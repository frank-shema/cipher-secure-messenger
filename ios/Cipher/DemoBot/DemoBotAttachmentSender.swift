#if DEBUG
import CipherCore
import CipherCrypto
import CipherNetworking
import Foundation

/// Echo's attachment path is the app's own `SendAttachmentUseCase`: render → seal with a fresh
/// per-file key → upload only the sealed bytes → describe the blob (key, digest, type, thumbnail)
/// inside the encrypted payload. Reusing the Core use case keeps the demo honest about what the person
/// would see from any other client, and keeps one pipeline to fix when the protocol moves.
struct DemoBotAttachmentSender: Sendable {
    struct Request: Sendable {
        var conversationId: ConversationID
        var caption: String
        var flags: MessageFlags
        var replyTo: MessageID?
        var expiresAt: Date?
        var seed: UInt64
    }

    private let useCase: SendAttachmentUseCase

    init(stack: MessagingStack, attachments: any AttachmentGateway) {
        useCase = SendAttachmentUseCase(
            currentUserId: stack.account.id,
            messages: stack.messages,
            conversations: stack.conversations,
            outbox: stack.outbox,
            crypto: stack.crypto,
            conversationGateway: stack.conversationGateway,
            blobs: DemoBotBlobGateway(gateway: attachments),
            hasher: DemoBotBlobHasher(),
            clock: stack.clock
        )
    }

    /// Draws and sends one generated picture. Rendering runs on the caller's executor, which for the
    /// responder is the cooperative pool; sealing and hashing are moved off by the use case itself.
    func sendGeneratedImage(_ request: Request) async throws -> Message {
        let rendered = try DemoBotImageFactory.render(seed: request.seed)
        let draft = AttachmentDraft(
            data: rendered.png,
            mimeType: "image/png",
            filename: "echo-gradient.png",
            width: rendered.width,
            height: rendered.height,
            thumbnail: rendered.thumbnail
        )
        let coreRequest = SendAttachmentUseCase.Request(
            conversationId: request.conversationId,
            draft: draft,
            caption: request.caption,
            flags: request.flags,
            replyTo: request.replyTo,
            expiresAt: request.expiresAt
        )
        return try await useCase.execute(coreRequest)
    }
}

/// Core's callback-based blob port over the networking gateway. Echo never shows progress, so the
/// stream is simply not observed; the gateway finishes it on its own.
struct DemoBotBlobGateway: AttachmentBlobGateway {
    private let gateway: any AttachmentGateway

    init(gateway: any AttachmentGateway) {
        self.gateway = gateway
    }

    func upload(
        _ sealedBlob: Data,
        conversationId: ConversationID,
        expiresAt: Date?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> BlobID {
        let descriptor = try await gateway.upload(sealedBlob, conversationId: conversationId, expiresAt: expiresAt, progress: nil)
        onProgress(1)
        return descriptor.blobId
    }

    func download(blobId: BlobID, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        let data = try await gateway.download(blobId: blobId, progress: nil)
        onProgress(1)
        return data
    }
}

/// `BlobHashing` over the crypto package's digest helper, so the demo and the app hash identically.
struct DemoBotBlobHasher: BlobHashing {
    func sha256Hex(_ data: Data) -> String {
        AttachmentCipher.sha256Hex(data)
    }
}
#endif
