import CipherCore
import CryptoKit
import Foundation

/// Failures the decoy ports raise. Worded as ordinary network trouble because they are shown inside
/// the decoy, where nothing may hint that the relay was never contacted.
enum DecoyError: Error, LocalizedError, Hashable, Sendable {
    case relayUnreachable
    case conversationMissing

    var errorDescription: String? {
        switch self {
        case .relayUnreachable:
            String(localized: "decoy.error.relayUnreachable", defaultValue: "Couldn't reach the relay. Try again later.")
        case .conversationMissing:
            String(localized: "decoy.error.conversationMissing", defaultValue: "This conversation is no longer available.")
        }
    }
}

struct DecoyConversationsObserver: ConversationsObserving {
    let store: PreviewMessagingStore

    func execute() async -> AsyncStream<[Conversation]> {
        await store.observeAll()
    }
}

struct DecoyConversationObserver: ConversationObserving {
    let store: PreviewMessagingStore

    func execute(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        await store.observe(conversationId: conversationId)
    }
}

struct DecoyReadMarker: ConversationReadMarking {
    let store: PreviewMessagingStore

    func execute(conversationId: ConversationID) async throws -> [MessageID] {
        try await store.markRead(conversationId: conversationId, at: Date())
    }
}

/// Pull-to-refresh spins for a moment and finds nothing, exactly like a quiet real inbox.
struct DecoyConversationSyncer: ConversationSyncing {
    func execute(conversationId: ConversationID) async throws -> [Message] {
        try await Task.sleep(for: .milliseconds(500))
        return []
    }
}

/// Resolves decoy contacts by username; anyone else is "unreachable" so no real lookup ever leaves the
/// device while the decoy is showing.
struct DecoyConversationStarter: ConversationStarting {
    let store: PreviewMessagingStore

    func execute(username: String) async throws -> Conversation {
        try await Task.sleep(for: .milliseconds(700))
        let all: [Conversation] = try await store.fetchAll()
        guard let existing = all.first(where: { $0.contact.user.username == username }) else {
            throw DecoyError.relayUnreachable
        }
        return existing
    }
}

/// Stores the message locally and walks it to "delivered" so the composer behaves as usual. Nothing is
/// sealed or sent: the decoy contacts have no relay accounts, and a real send would leave a trace.
struct DecoyMessageSender: MessageSending {
    let store: PreviewMessagingStore
    let localUserId: UserID
    let now: @Sendable () -> Date

    func execute(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date?) async throws -> Message {
        guard let conversation = try await store.fetch(id: conversationId) else { throw DecoyError.conversationMissing }
        if let reaction = payload.reaction {
            return try await apply(reaction)
        }
        let counter = try await store.nextCounter(conversationId: conversationId)
        let message = Message(
            id: MessageID(), conversationId: conversationId, senderId: localUserId, recipientId: conversation.contact.id,
            direction: .outgoing, content: payload.content, flags: payload.flags, replyToId: payload.replyToId, counter: counter,
            sentAt: now(), serverCreatedAt: nil, status: .sending, expiresAt: expiresAt, reactions: []
        )
        try await store.upsert(message)
        try await store.updateLastMessage(conversationId: conversationId, message: message)
        Task { await settle(message.id) }
        return message
    }

    func retry(messageId: MessageID) async throws -> Message {
        guard var message = try await store.fetch(id: messageId) else { throw DecoyError.conversationMissing }
        message.status = .sending
        try await store.upsert(message)
        let id = message.id
        Task { await settle(id) }
        return message
    }

    private func apply(_ reaction: Reaction) async throws -> Message {
        guard var target = try await store.fetch(id: reaction.targetId) else { throw DecoyError.conversationMissing }
        if reaction.remove {
            target.reactions.removeAll { $0.emoji == reaction.emoji }
        } else if !target.reactions.contains(where: { $0.emoji == reaction.emoji }) {
            target.reactions.append(reaction)
        }
        try await store.upsert(target)
        return target
    }

    private func settle(_ id: MessageID) async {
        try? await Task.sleep(for: .milliseconds(350))
        try? await store.updateStatus(ids: [id], status: .sent, at: now())
        try? await Task.sleep(for: .milliseconds(600))
        try? await store.updateStatus(ids: [id], status: .delivered, at: now())
    }
}

/// Typing goes nowhere and nobody types back; the stream stays open so the chat's observer task keeps
/// its normal lifetime.
struct DecoyTypingSignaller: TypingSignaller {
    func setTyping(_ isTyping: Bool, in conversationId: ConversationID) async {}

    func incomingTyping(in conversationId: ConversationID) async -> AsyncStream<TypingSignal> {
        AsyncStream { _ in }
    }
}

/// Synthesises a plausible envelope for the Server's-Eye view: bytes derived from the message id, so
/// the same bubble always flips to the same "ciphertext". Not cryptography, and not presented as such.
struct DecoyEnvelopeProvider: EnvelopeProviding {
    let store: PreviewMessagingStore

    func envelope(for messageId: MessageID) async throws -> Envelope? {
        guard let message = try await store.fetch(id: messageId) else { return nil }
        let bodyLength: Int
        if case .text(let text) = message.content { bodyLength = text.utf8.count } else { bodyLength = 96 }
        return Envelope(
            id: message.id, conversationId: message.conversationId, senderId: message.senderId, recipientId: message.recipientId,
            counter: message.counter, timestamp: message.sentAt.epochMillis,
            ciphertext: Self.noise(seed: "ct|\(message.id.description)", count: bodyLength + 44),
            signature: Self.noise(seed: "sig|\(message.id.description)", count: 64),
            expiresAt: message.expiresAt?.epochMillis
        )
    }

    /// SHA-256 in counter mode: deterministic, uniformly distributed bytes of any length.
    static func noise(seed: String, count: Int) -> Data {
        var output = Data(capacity: count)
        var block: UInt32 = 0
        while output.count < count {
            let digest = SHA256.hash(data: Data("\(seed)|\(block)".utf8))
            output.append(contentsOf: digest.prefix(count - output.count))
            block += 1
        }
        return output
    }
}
