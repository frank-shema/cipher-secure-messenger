import CipherCore
import Foundation

/// `AttachmentGateway` over `/attachments/*`, with real transfer progress from URLSession.
public struct RemoteAttachmentGateway: AttachmentGateway {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func upload(
        _ blob: Data,
        conversationId: ConversationID,
        expiresAt: Date?,
        progress: TransferProgress?
    ) async throws -> BlobDescriptor {
        guard blob.count <= UploadAttachmentEndpoint.maxBlobBytes else {
            NetLog.attachments.notice("refused upload of \(blob.count, privacy: .public) bytes: over the relay limit")
            progress?.finish()
            throw APIError.payloadTooLarge(nil)
        }
        let endpoint = UploadAttachmentEndpoint(
            blob: blob,
            conversationId: conversationId,
            expiresAtMillis: expiresAt?.epochMillis
        )
        let descriptor = try await client.send(endpoint, progress: progress)
        NetLog.attachments.info(
            "uploaded blob \(descriptor.blobId.description, privacy: .public) (\(descriptor.size, privacy: .public) bytes)"
        )
        return descriptor.toDomain()
    }

    public func download(blobId: BlobID, progress: TransferProgress?) async throws -> Data {
        let response = try await client.send(DownloadAttachmentEndpoint(blobId: blobId), progress: progress)
        NetLog.attachments.info(
            "downloaded blob \(blobId.description, privacy: .public) (\(response.data.count, privacy: .public) bytes)"
        )
        return response.data
    }
}
