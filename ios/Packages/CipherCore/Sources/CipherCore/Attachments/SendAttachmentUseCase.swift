import Foundation

/// Seals a file with a fresh key, uploads the blob, then sends the message that carries the key.
///
/// The message id is chosen *before* the upload and a placeholder row (status `sending`, digest empty)
/// is persisted immediately, so the chat shows the bubble with a progress ring from the first byte.
/// Once the blob is stored, `SendMessageUseCase` runs with that same id and replaces the placeholder
/// with the real attachment, the reserved counter and the sealed envelope. A placeholder is never
/// enqueued in the outbox: only a fully uploaded attachment may ever be sealed into an envelope.
public struct SendAttachmentUseCase: Sendable {
    /// Everything about one send that Core needs from the composer.
    public struct Request: Sendable {
        public var conversationId: ConversationID
        public var draft: AttachmentDraft
        public var caption: String?
        public var flags: MessageFlags
        public var replyTo: MessageID?
        public var expiresAt: Date?

        public init(
            conversationId: ConversationID,
            draft: AttachmentDraft,
            caption: String? = nil,
            flags: MessageFlags = .none,
            replyTo: MessageID? = nil,
            expiresAt: Date? = nil
        ) {
            self.conversationId = conversationId
            self.draft = draft
            self.caption = caption
            self.flags = flags
            self.replyTo = replyTo
            self.expiresAt = expiresAt
        }
    }

    public typealias ProgressHandler = @Sendable (MessageID, AttachmentUploadPhase) -> Void

    private let currentUserId: UserID
    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let outbox: any OutboxRepository
    private let crypto: any MessageCryptoService
    private let conversationGateway: any ConversationGateway
    private let blobs: any AttachmentBlobGateway
    private let hasher: any BlobHashing
    private let clock: any Clock
    private let uuids: any UUIDGenerator
    private let pending: PendingAttachmentSends

    public init(
        currentUserId: UserID,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        outbox: any OutboxRepository,
        crypto: any MessageCryptoService,
        conversationGateway: any ConversationGateway,
        blobs: any AttachmentBlobGateway,
        hasher: any BlobHashing,
        clock: any Clock = SystemClock(),
        uuids: any UUIDGenerator = SystemUUIDGenerator(),
        pending: PendingAttachmentSends = PendingAttachmentSends()
    ) {
        self.currentUserId = currentUserId
        self.messages = messages
        self.conversations = conversations
        self.outbox = outbox
        self.crypto = crypto
        self.conversationGateway = conversationGateway
        self.blobs = blobs
        self.hasher = hasher
        self.clock = clock
        self.uuids = uuids
        self.pending = pending
    }

    /// Persists the placeholder, then seals, uploads and sends. Returns the message as persisted after
    /// the send attempt (see `SendMessageUseCase.execute`). Upload failures leave the message `failed`
    /// with its bytes retained in memory so `retry(messageId:)` can re-upload without a new pick.
    public func execute(_ request: Request, onProgress: @escaping ProgressHandler = { _, _ in }) async throws -> Message {
        try validate(request.draft)
        let conversation = try await requireConversation(request.conversationId)
        let messageId = MessageID(uuids.next())
        let key = crypto.attachmentKey()
        let placeholder = makePlaceholder(id: messageId, request: request, key: key, recipientId: conversation.contact.id)
        try await messages.upsert(placeholder)
        try await conversations.updateLastMessage(conversationId: request.conversationId, message: placeholder)
        await pending.store(.init(request: request, key: key, attempts: 0), for: messageId)
        CoreLog.attachments.info(
            "attachment send started message=\(messageId.description, privacy: .public) bytes=\(request.draft.size, privacy: .public)"
        )
        return try await transfer(messageId: messageId, request: request, key: key, onProgress: onProgress)
    }

    /// Re-uploads from memory when the blob never made it; otherwise defers to the ordinary message
    /// retry (outbox replay or re-seal), because a stored digest proves the blob is already on the relay.
    public func retry(
        messageId: MessageID,
        onProgress: @escaping ProgressHandler = { _, _ in }
    ) async throws -> Message {
        if let entry = await pending.entry(for: messageId) {
            await pending.markAttempt(for: messageId)
            try await setStatus(.sending, messageId: messageId)
            return try await transfer(messageId: messageId, request: entry.request, key: entry.key, onProgress: onProgress)
        }
        guard let message = try await messages.fetch(id: messageId) else {
            throw CipherCoreError.messageNotFound(messageId)
        }
        if message.direction == .outgoing,
           case .attachment(let attachment, _) = message.content,
           attachment.sha256.isEmpty {
            try await setStatus(.failed, messageId: messageId)
            CoreLog.attachments.notice("orphaned attachment placeholder message=\(messageId.description, privacy: .public)")
            throw AttachmentError.uploadIncomplete(messageId)
        }
        return try await makeSender(messageId: messageId).retry(messageId: messageId)
    }

    /// Plain sends go straight through, so one object can serve as the chat's only sender.
    public func send(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date?) async throws -> Message {
        try await makeSender(messageId: MessageID(uuids.next()))
            .execute(conversationId: conversationId, payload: payload, expiresAt: expiresAt)
    }

    // MARK: Pipeline

    private func transfer(
        messageId: MessageID,
        request: Request,
        key: Data,
        onProgress: @escaping ProgressHandler
    ) async throws -> Message {
        let attachment: Attachment
        do {
            attachment = try await uploadSealed(messageId: messageId, request: request, key: key, onProgress: onProgress)
        } catch {
            try await setStatus(.failed, messageId: messageId)
            onProgress(messageId, .failed)
            let failure = String(describing: type(of: error))
            CoreLog.attachments.error(
                "attachment upload failed message=\(messageId.description, privacy: .public) error=\(failure, privacy: .public)"
            )
            throw error
        }
        await pending.remove(messageId)
        onProgress(messageId, .sending)
        let payload = MessagePayload.attachment(attachment, caption: request.caption, flags: request.flags, replyTo: request.replyTo)
        do {
            let sent = try await makeSender(messageId: messageId)
                .execute(conversationId: request.conversationId, payload: payload, expiresAt: request.expiresAt)
            onProgress(messageId, .completed)
            return sent
        } catch {
            onProgress(messageId, .failed)
            throw error
        }
    }

    private func uploadSealed(
        messageId: MessageID,
        request: Request,
        key: Data,
        onProgress: @escaping ProgressHandler
    ) async throws -> Attachment {
        onProgress(messageId, .sealing)
        let crypto = crypto
        let plaintext = request.draft.data
        let sealed: Data
        do {
            sealed = try await BackgroundWork.run { () throws(CryptoError) in try crypto.sealBlob(plaintext, key: key) }
        } catch {
            throw AttachmentError.sealingFailed(error)
        }
        let hasher = hasher
        let digest = await BackgroundWork.run { () throws(Never) in hasher.sha256Hex(sealed) }
        onProgress(messageId, .uploading(fraction: 0))
        let blobId = try await blobs.upload(sealed, conversationId: request.conversationId, expiresAt: request.expiresAt) { fraction in
            onProgress(messageId, .uploading(fraction: fraction))
        }
        let blob = blobId.description
        let bytes = sealed.count
        let message = messageId.description
        CoreLog.attachments.info("blob stored message=\(message, privacy: .public) blob=\(blob, privacy: .public) bytes=\(bytes)")
        return Attachment(
            blobId: blobId,
            key: key,
            sha256: digest,
            mimeType: request.draft.mimeType,
            filename: request.draft.filename,
            size: request.draft.size,
            width: request.draft.width,
            height: request.draft.height,
            thumbnail: request.draft.thumbnail
        )
    }

    // MARK: Helpers

    private func validate(_ draft: AttachmentDraft) throws {
        guard draft.size <= AttachmentLimits.maxPlaintextBytes else {
            throw AttachmentError.tooLarge(bytes: draft.size, limit: AttachmentLimits.maxPlaintextBytes)
        }
        if let thumbnail = draft.thumbnail, thumbnail.count > AttachmentLimits.maxThumbnailBytes {
            throw AttachmentError.thumbnailTooLarge(bytes: thumbnail.count)
        }
    }

    private func requireConversation(_ id: ConversationID) async throws -> Conversation {
        guard let conversation = try await conversations.fetch(id: id) else {
            throw CipherCoreError.conversationNotFound(id)
        }
        return conversation
    }

    /// The row shown while uploading. An empty digest marks it as "not on the relay yet"; the blob id
    /// is a throwaway so the value is well-formed without pointing at anything.
    private func makePlaceholder(id: MessageID, request: Request, key: Data, recipientId: UserID) -> Message {
        let attachment = Attachment(
            blobId: BlobID(uuids.next()),
            key: key,
            sha256: "",
            mimeType: request.draft.mimeType,
            filename: request.draft.filename,
            size: request.draft.size,
            width: request.draft.width,
            height: request.draft.height,
            thumbnail: request.draft.thumbnail
        )
        return Message(
            id: id,
            conversationId: request.conversationId,
            senderId: currentUserId,
            recipientId: recipientId,
            direction: .outgoing,
            content: .attachment(attachment, caption: request.caption),
            flags: request.flags,
            replyToId: request.replyTo,
            counter: 0,
            sentAt: clock.now(),
            serverCreatedAt: nil,
            status: .sending,
            expiresAt: request.expiresAt,
            reactions: []
        )
    }

    private func setStatus(_ status: MessageStatus, messageId: MessageID) async throws {
        guard var message = try await messages.fetch(id: messageId) else { return }
        message.status = status
        try await messages.upsert(message)
    }

    private func makeSender(messageId: MessageID) -> SendMessageUseCase {
        SendMessageUseCase(
            currentUserId: currentUserId,
            messages: messages,
            conversations: conversations,
            outbox: outbox,
            crypto: crypto,
            gateway: conversationGateway,
            clock: clock,
            uuids: PresetUUIDGenerator(uuid: messageId.uuid)
        )
    }
}
