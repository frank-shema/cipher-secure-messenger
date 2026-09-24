import Foundation

/// Sends a message optimistically: the row appears locally as `sending` before any network work,
/// the sealed envelope is queued durably, and the relay's ack (or failure) reconciles the status.
public struct SendMessageUseCase: Sendable {
    private let currentUserId: UserID
    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let outbox: any OutboxRepository
    private let crypto: any MessageCryptoService
    private let gateway: any ConversationGateway
    private let clock: any Clock
    private let uuids: any UUIDGenerator

    public init(
        currentUserId: UserID,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        outbox: any OutboxRepository,
        crypto: any MessageCryptoService,
        gateway: any ConversationGateway,
        clock: any Clock = SystemClock(),
        uuids: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        self.currentUserId = currentUserId
        self.messages = messages
        self.conversations = conversations
        self.outbox = outbox
        self.crypto = crypto
        self.gateway = gateway
        self.clock = clock
        self.uuids = uuids
    }

    /// Returns the message as persisted after the send attempt: `sent` on ack, `sending` when the
    /// failure was transient (it stays in the outbox for `FlushOutboxUseCase`). A permanent rejection
    /// persists `failed` and rethrows the transport error so the UI can explain it.
    public func execute(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date? = nil) async throws -> Message {
        try payload.validate()
        let conversation = try await requireConversation(conversationId)
        let recipientKeys = try requireKeys(of: conversation.contact)
        let now = clock.now()
        let counter = try await messages.nextCounter(conversationId: conversationId)
        let message = Message(
            id: MessageID(uuids.next()),
            conversationId: conversationId,
            senderId: currentUserId,
            recipientId: conversation.contact.id,
            direction: .outgoing,
            content: payload.content,
            flags: payload.flags,
            replyToId: payload.replyToId,
            counter: counter,
            sentAt: now,
            serverCreatedAt: nil,
            status: .sending,
            expiresAt: expiresAt,
            reactions: []
        )
        try await persistOptimistically(message)
        let envelope = try await seal(payload, for: recipientKeys, message: message)
        try await outbox.enqueue(OutboxItem(messageId: message.id, envelope: envelope, enqueuedAt: now))
        return try await transmit(envelope, message: message)
    }

    /// Re-sends a `failed` or stuck `sending` message. The queued envelope is reused when present;
    /// otherwise the payload is re-sealed with the SAME id, counter and timestamp so the relay treats it
    /// as the same message and no counter is burned.
    public func retry(messageId: MessageID) async throws -> Message {
        guard let message = try await messages.fetch(id: messageId) else {
            throw CipherCoreError.messageNotFound(messageId)
        }
        guard message.direction == .outgoing, message.status == .failed || message.status == .sending else {
            return message
        }
        let sending = try await markSending(message)
        if let queued = try await outbox.item(messageId: messageId) {
            return try await transmit(queued.envelope, message: sending)
        }
        guard let payload = MessagePayload(content: message.content, flags: message.flags, replyToId: message.replyToId) else {
            throw CipherCoreError.messageNotRetryable(messageId)
        }
        let conversation = try await requireConversation(message.conversationId)
        let recipientKeys = try requireKeys(of: conversation.contact)
        let envelope = try await seal(payload, for: recipientKeys, message: sending)
        try await outbox.enqueue(OutboxItem(messageId: message.id, envelope: envelope, enqueuedAt: clock.now()))
        return try await transmit(envelope, message: sending)
    }

    private func requireConversation(_ id: ConversationID) async throws -> Conversation {
        guard let conversation = try await conversations.fetch(id: id) else {
            throw CipherCoreError.conversationNotFound(id)
        }
        return conversation
    }

    private func requireKeys(of contact: Contact) throws -> PublicKeyBundle {
        guard let keys = contact.keys, keys.hasValidKeyLengths else {
            throw CipherCoreError.recipientKeysUnavailable(contact.id)
        }
        return keys
    }

    private func persistOptimistically(_ message: Message) async throws {
        try await messages.upsert(message)
        if case .reaction(let reaction) = message.content {
            try await ReactionApplier.apply(reaction, using: messages)
        }
        try await conversations.updateLastMessage(conversationId: message.conversationId, message: message)
    }

    private func markSending(_ message: Message) async throws -> Message {
        var updated = message
        updated.status = .sending
        try await messages.upsert(updated)
        return updated
    }

    private func seal(_ payload: MessagePayload, for recipientKeys: PublicKeyBundle, message: Message) async throws -> Envelope {
        let header = EnvelopeHeader(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            recipientId: message.recipientId,
            counter: message.counter,
            timestampMillis: message.sentAt.epochMillis,
            expiresAtMillis: message.expiresAt?.epochMillis
        )
        do {
            return try await crypto.seal(payload: payload, for: recipientKeys, header: header)
        } catch {
            var failed = message
            failed.status = .failed
            try await messages.upsert(failed)
            CoreLog.useCases.error("sealing failed for message \(message.id.description, privacy: .public)")
            throw CipherCoreError.sealingFailed(error)
        }
    }

    private func transmit(_ envelope: Envelope, message: Message) async throws -> Message {
        let reconciler = AckReconciler(messages: messages, conversations: conversations, outbox: outbox, clock: clock)
        switch try await reconciler.send(envelope, for: message, via: gateway) {
        case .sent(let sent):
            return sent
        case .deferred(let queued):
            return queued
        case .rejected(_, let error):
            throw error
        }
    }
}
