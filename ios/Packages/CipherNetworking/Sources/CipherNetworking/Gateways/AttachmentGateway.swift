import CipherCore
import Foundation

/// What the relay knows about a stored blob (PROTOCOL.md §1.4). The decryption key, MIME type and
/// filename never reach the relay; they travel inside the message ciphertext as `Attachment`.
public struct BlobDescriptor: Hashable, Sendable {
    public var blobId: BlobID
    public var size: Int
    public var createdAt: Date
    public var expiresAt: Date?

    public init(blobId: BlobID, size: Int, createdAt: Date, expiresAt: Date?) {
        self.blobId = blobId
        self.size = size
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

/// Moves *already encrypted* blobs to and from the relay. Callers seal with `MessageCryptoService.sealBlob`
/// first; this port never sees plaintext bytes. Progress is optional so background flushes can skip it.
public protocol AttachmentGateway: Sendable {
    /// Uploads a sealed blob scoped to a conversation. `expiresAt` lets the relay purge disappearing
    /// attachments on its own clock.
    func upload(_ blob: Data, conversationId: ConversationID, expiresAt: Date?, progress: TransferProgress?) async throws -> BlobDescriptor
    /// Downloads a sealed blob. Only participants of the blob's conversation are allowed (403 otherwise).
    func download(blobId: BlobID, progress: TransferProgress?) async throws -> Data
}
