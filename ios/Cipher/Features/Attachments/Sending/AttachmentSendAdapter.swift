import CipherCore
import Foundation

/// Bridges the chat's ports to `SendAttachmentUseCase`. It is both the `AttachmentSending` the
/// composer hands a staged pick to and the `MessageSending` every other send goes through, so a
/// retry on an attachment whose upload failed re-uploads instead of re-sealing a placeholder.
struct AttachmentSendAdapter: AttachmentSending, MessageSending {
    private let useCase: SendAttachmentUseCase
    private let drafts: StagedDraftStore
    private let transfers: AttachmentTransferCenter

    init(useCase: SendAttachmentUseCase, drafts: StagedDraftStore, transfers: AttachmentTransferCenter) {
        self.useCase = useCase
        self.drafts = drafts
        self.transfers = transfers
    }

    func send(_ request: AttachmentSendRequest) async throws -> Message {
        guard let draft = await drafts.take(request.staged.id) else {
            AttachmentsLog.transfer.error("staged draft missing for staged id \(request.staged.id.uuidString, privacy: .public)")
            throw AttachmentError.draftUnavailable
        }
        let coreRequest = SendAttachmentUseCase.Request(
            conversationId: request.conversationId,
            draft: draft,
            caption: request.caption,
            flags: request.flags,
            replyTo: request.replyTo,
            expiresAt: request.expiresAt
        )
        return try await useCase.execute(coreRequest, onProgress: transfers.uploadReporter())
    }

    func execute(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date?) async throws -> Message {
        try await useCase.send(conversationId: conversationId, payload: payload, expiresAt: expiresAt)
    }

    func retry(messageId: MessageID) async throws -> Message {
        try await useCase.retry(messageId: messageId, onProgress: transfers.uploadReporter())
    }
}
