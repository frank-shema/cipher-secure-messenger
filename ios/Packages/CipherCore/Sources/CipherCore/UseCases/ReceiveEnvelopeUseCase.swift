import Foundation

/// Turns a relay-stored envelope into a local message. Failures to verify or decrypt are persisted as
/// `.tampered` messages so the person sees a warning where the message would be; replays are surfaced
/// but never stored twice. The caller acknowledges over the socket only after this returns.
public struct ReceiveEnvelopeUseCase: Sendable {
    private let currentUserId: UserID
    private let contacts: any ContactRepository
    private let keyDirectory: any KeyDirectoryGateway
    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let crypto: any MessageCryptoService
    private let replayGuard: any ReplayGuard
    private let clock: any Clock

    public init(
        currentUserId: UserID,
        contacts: any ContactRepository,
        keyDirectory: any KeyDirectoryGateway,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        crypto: any MessageCryptoService,
        replayGuard: any ReplayGuard,
        clock: any Clock = SystemClock()
    ) {
        self.currentUserId = currentUserId
        self.contacts = contacts
        self.keyDirectory = keyDirectory
        self.messages = messages
        self.conversations = conversations
        self.crypto = crypto
        self.replayGuard = replayGuard
        self.clock = clock
    }

    /// Idempotent by message id: a re-pushed envelope returns the stored message unchanged.
    public func execute(_ stored: StoredEnvelope) async throws -> Message {
        let envelope = stored.envelope
        if let existing = try await messages.fetch(id: envelope.id) {
            return existing
        }
        let direction: MessageDirection = envelope.senderId == currentUserId ? .outgoing : .incoming
        let peerId = direction == .incoming ? envelope.senderId : envelope.recipientId
        let peer = try await resolvePeer(peerId)
        if direction == .incoming, try await isReplay(envelope) {
            return try await replayOutcome(for: stored, direction: direction)
        }
        let message = await open(stored, direction: direction, peer: peer)
        if direction == .incoming, !message.content.isTampered {
            try await replayGuard.markSeen(senderId: envelope.senderId, conversationId: envelope.conversationId, counter: envelope.counter)
        }
        try await persist(message, peer: peer)
        return message
    }

    private func resolvePeer(_ peerId: UserID) async throws -> Contact {
        if let contact = try await contacts.fetch(userId: peerId), let keys = contact.keys, keys.hasValidKeyLengths {
            return contact
        }
        let remote: RemoteKeyBundle
        do {
            remote = try await keyDirectory.fetchKeys(userId: peerId)
        } catch {
            let errorName = String(describing: type(of: error))
            CoreLog.useCases.error("keys unavailable for \(peerId.description, privacy: .public): \(errorName, privacy: .public)")
            throw CipherCoreError.peerKeysUnavailable(peerId)
        }
        return try await ContactPinning.pin(remote, into: contacts, now: clock.now())
    }

    private func isReplay(_ envelope: Envelope) async throws -> Bool {
        try await replayGuard.isReplay(senderId: envelope.senderId, conversationId: envelope.conversationId, counter: envelope.counter)
    }

    private func replayOutcome(for stored: StoredEnvelope, direction: MessageDirection) async throws -> Message {
        let envelope = stored.envelope
        CoreLog.useCases.warning("replayed counter \(envelope.counter) in \(envelope.conversationId.description, privacy: .public)")
        if let original = try await messages.fetch(
            conversationId: envelope.conversationId,
            senderId: envelope.senderId,
            counter: envelope.counter
        ) {
            return original
        }
        return makeMessage(from: stored, direction: direction, content: .tampered(.replayed), payload: nil)
    }

    private func open(_ stored: StoredEnvelope, direction: MessageDirection, peer: Contact) async -> Message {
        guard let keys = peer.keys else {
            return makeMessage(from: stored, direction: direction, content: .tampered(.unknownSender), payload: nil)
        }
        do {
            let payload = try await crypto.open(stored.envelope, peer: keys, myUserId: currentUserId)
            return makeMessage(from: stored, direction: direction, content: payload.content, payload: payload)
        } catch {
            let reason = error.tamperReason
            CoreLog.useCases.error("message \(stored.id.description, privacy: .public) rejected: \(reason.rawValue, privacy: .public)")
            return makeMessage(from: stored, direction: direction, content: .tampered(reason), payload: nil)
        }
    }

    private func makeMessage(
        from stored: StoredEnvelope,
        direction: MessageDirection,
        content: MessageContent,
        payload: MessagePayload?
    ) -> Message {
        let envelope = stored.envelope
        return Message(
            id: envelope.id,
            conversationId: envelope.conversationId,
            senderId: envelope.senderId,
            recipientId: envelope.recipientId,
            direction: direction,
            content: content,
            flags: payload?.flags ?? .none,
            replyToId: payload?.replyToId,
            counter: envelope.counter,
            sentAt: envelope.sentAt,
            serverCreatedAt: stored.serverCreatedAt,
            status: stored.status.messageStatus,
            expiresAt: envelope.expiresAtDate,
            reactions: []
        )
    }

    private func persist(_ message: Message, peer: Contact) async throws {
        try await messages.upsert(message)
        if case .reaction(let reaction) = message.content {
            try await ReactionApplier.apply(reaction, using: messages)
        }
        let conversation = try await ensureConversation(message.conversationId, peer: peer, at: message.effectiveTimestamp)
        try await conversations.updateLastMessage(conversationId: conversation.id, message: message)
        if message.direction == .incoming, message.status != .read, !message.content.isReaction {
            try await conversations.setUnread(conversationId: conversation.id, count: conversation.unreadCount + 1)
        }
    }

    private func ensureConversation(_ id: ConversationID, peer: Contact, at date: Date) async throws -> Conversation {
        if let existing = try await conversations.fetch(id: id) {
            return existing
        }
        let created = Conversation(id: id, contact: peer, lastMessage: nil, unreadCount: 0, updatedAt: date, disappearingTimer: nil)
        try await conversations.upsert(created)
        return created
    }
}
