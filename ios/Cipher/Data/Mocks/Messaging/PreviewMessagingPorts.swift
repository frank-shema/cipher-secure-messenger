import CipherCore
import Foundation

/// Failures the preview ports raise on purpose so error paths render in previews too.
enum PreviewMessagingError: Error, LocalizedError, Hashable, Sendable {
    case userNotFound(String)
    case relayRejected

    var errorDescription: String? {
        switch self {
        case .userNotFound(let username):
            String(localized: "preview.error.userNotFound", defaultValue: "No user named @\(username) exists.")
        case .relayRejected:
            String(localized: "preview.error.relayRejected", defaultValue: "The relay rejected this message.")
        }
    }
}

/// Persists an optimistic message, walks it through sent → delivered → read on a timer and, when
/// `echoes` is on, answers with a typed-out reply so previews feel alive. A body containing "fail"
/// is rejected, which is how the failed bubble in the fixtures gets exercised interactively.
struct PreviewMessageSender: MessageSending {
    let store: PreviewMessagingStore
    let typing: PreviewTypingSignaller
    let currentUserId: UserID
    var echoes = true

    func execute(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date?) async throws -> Message {
        guard let conversation = try await store.fetch(id: conversationId) else { throw PreviewMessagingError.relayRejected }
        if let reaction = payload.reaction {
            return try await apply(reaction, in: conversation)
        }
        let counter = try await store.nextCounter(conversationId: conversationId)
        var message = Message(
            id: MessageID(), conversationId: conversationId, senderId: currentUserId, recipientId: conversation.contact.id,
            direction: .outgoing, content: payload.content, flags: payload.flags, replyToId: payload.replyToId, counter: counter,
            sentAt: Date(), serverCreatedAt: nil, status: .sending, expiresAt: expiresAt, reactions: []
        )
        try await store.upsert(message)
        if payload.body?.localizedCaseInsensitiveContains("fail") == true {
            message.status = .failed
            try await store.upsert(message)
            throw PreviewMessagingError.relayRejected
        }
        Task { [message] in await advance(message, in: conversation) }
        return message
    }

    func retry(messageId: MessageID) async throws -> Message {
        guard var message = try await store.fetch(id: messageId),
              let conversation = try await store.fetch(id: message.conversationId) else {
            throw PreviewMessagingError.relayRejected
        }
        message.status = .sending
        try await store.upsert(message)
        Task { [message] in await advance(message, in: conversation) }
        return message
    }

    private func apply(_ reaction: Reaction, in conversation: Conversation) async throws -> Message {
        guard var target = try await store.fetch(id: reaction.targetId) else { throw PreviewMessagingError.relayRejected }
        if reaction.remove {
            target.reactions.removeAll { $0.emoji == reaction.emoji }
        } else if !target.reactions.contains(where: { $0.emoji == reaction.emoji }) {
            target.reactions.append(reaction)
        }
        try await store.upsert(target)
        return target
    }

    private func advance(_ message: Message, in conversation: Conversation) async {
        try? await Task.sleep(for: .milliseconds(500))
        try? await store.updateStatus(ids: [message.id], status: .sent, at: Date())
        try? await Task.sleep(for: .milliseconds(700))
        try? await store.updateStatus(ids: [message.id], status: .delivered, at: Date())
        try? await store.updateLastMessage(conversationId: conversation.id, message: message)
        guard echoes, case .text(let body) = message.content else { return }
        await typing.simulate(isTyping: true, from: conversation.contact.id, in: conversation.id)
        try? await Task.sleep(for: .milliseconds(1_600))
        try? await store.updateStatus(ids: [message.id], status: .read, at: Date())
        await typing.simulate(isTyping: false, from: conversation.contact.id, in: conversation.id)
        let reply = Message(
            id: MessageID(), conversationId: conversation.id, senderId: conversation.contact.id, recipientId: currentUserId,
            direction: .incoming, content: .text(echoLine(for: body)), flags: .none, replyToId: message.id, counter: message.counter + 100,
            sentAt: Date(), serverCreatedAt: Date(), status: .delivered, expiresAt: nil, reactions: []
        )
        try? await store.upsert(reply)
        try? await store.updateLastMessage(conversationId: conversation.id, message: reply)
    }

    private func echoLine(for body: String) -> String {
        body.hasSuffix("?") ? "Good question. Let me think about \"\(body.dropLast())\"." : "You said: \(body)"
    }
}

/// Records outgoing typing and lets tests or the echo sender inject incoming signals.
actor PreviewTypingSignaller: TypingSignaller {
    private var observers: [UUID: (ConversationID, AsyncStream<TypingSignal>.Continuation)] = [:]
    private(set) var outgoing: [(ConversationID, Bool)] = []

    init() {}

    func setTyping(_ isTyping: Bool, in conversationId: ConversationID) async {
        outgoing.append((conversationId, isTyping))
    }

    func incomingTyping(in conversationId: ConversationID) async -> AsyncStream<TypingSignal> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<TypingSignal>.makeStream()
        observers[key] = (conversationId, continuation)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(key) }
        }
        return stream
    }

    func simulate(isTyping: Bool, from userId: UserID, in conversationId: ConversationID) {
        let signal = TypingSignal(conversationId: conversationId, userId: userId, isTyping: isTyping)
        for (id, continuation) in observers.values where id == conversationId { continuation.yield(signal) }
    }

    private func remove(_ key: UUID) { observers.removeValue(forKey: key) }
}

/// Synthesises a plausible envelope for any message: the bytes are seeded from the id so the same
/// bubble always flips to the same "ciphertext". Nothing here is real cryptography.
struct PreviewEnvelopeProvider: EnvelopeProviding {
    let store: PreviewMessagingStore

    func envelope(for messageId: MessageID) async throws -> Envelope? {
        guard let message = try await store.fetch(id: messageId) else { return nil }
        let bodyLength: Int
        if case .text(let text) = message.content { bodyLength = text.utf8.count } else { bodyLength = 96 }
        return Envelope(
            id: message.id, conversationId: message.conversationId, senderId: message.senderId, recipientId: message.recipientId,
            counter: message.counter, timestamp: message.sentAt.epochMillis,
            ciphertext: Self.noise(seed: message.id.description, count: bodyLength + 44),
            signature: Self.noise(seed: "sig|\(message.id)", count: 64),
            expiresAt: message.expiresAt?.epochMillis
        )
    }

    static func noise(seed: String, count: Int) -> Data {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        for byte in seed.utf8 { state = (state ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            bytes.append(UInt8(truncatingIfNeeded: state))
        }
        return Data(bytes)
    }
}

/// Wraps the real Core scanner (it has no dependencies) or returns a fixed kind for screenshots.
struct PreviewSensitiveDetector: SensitiveContentDetecting {
    var fixed: SensitiveKind?
    private let real = CoreSensitiveContentDetector()

    init(fixed: SensitiveKind? = nil) {
        self.fixed = fixed
    }

    func detect(in text: String) async -> SensitiveKind? {
        if let fixed { return fixed }
        return await real.detect(in: text)
    }
}

/// Resolves fixture usernames to their conversations; anything else is "not found".
struct PreviewConversationStarter: ConversationStarting {
    let store: PreviewMessagingStore
    var delay: Duration = .milliseconds(600)

    func execute(username: String) async throws -> Conversation {
        try await Task.sleep(for: delay)
        let all: [Conversation] = try await store.fetchAll()
        guard let existing = all.first(where: { $0.contact.user.username == username }) else {
            throw PreviewMessagingError.userNotFound(username)
        }
        return existing
    }
}

/// Pretends to page the relay; there is nothing new in a preview.
struct PreviewConversationSyncer: ConversationSyncing {
    func execute(conversationId: ConversationID) async throws -> [Message] {
        try await Task.sleep(for: .milliseconds(400))
        return []
    }
}

struct PreviewReadMarker: ConversationReadMarking {
    let store: PreviewMessagingStore

    func execute(conversationId: ConversationID) async throws -> [MessageID] {
        try await store.markRead(conversationId: conversationId, at: Date())
    }
}

struct PreviewContactVerifier: ContactVerifying {
    let store: PreviewMessagingStore

    func execute(userId: UserID) async throws -> Contact {
        try await store.setTrust(userId: userId, trust: .verified(at: Date()))
        guard let contact = try await store.fetch(userId: userId) else { throw PreviewMessagingError.relayRejected }
        return contact
    }
}
