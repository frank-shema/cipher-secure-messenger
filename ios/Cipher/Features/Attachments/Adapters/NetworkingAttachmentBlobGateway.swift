import CipherCore
import CipherNetworking
import Foundation

/// Adapts the networking module's `AttachmentGateway` (stream-based progress) onto Core's
/// callback-based `AttachmentBlobGateway`, so Core never imports a transport type.
struct NetworkingAttachmentBlobGateway: AttachmentBlobGateway {
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
        let progress = TransferProgress()
        let relay = Task { for await fraction in progress.updates { onProgress(fraction) } }
        defer { relay.cancel() }
        let descriptor = try await gateway.upload(sealedBlob, conversationId: conversationId, expiresAt: expiresAt, progress: progress)
        return descriptor.blobId
    }

    func download(blobId: BlobID, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        let progress = TransferProgress()
        let relay = Task { for await fraction in progress.updates { onProgress(fraction) } }
        defer { relay.cancel() }
        return try await gateway.download(blobId: blobId, progress: progress)
    }
}
