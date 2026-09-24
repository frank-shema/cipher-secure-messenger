import Foundation

/// Moves *already sealed* blobs to and from the relay (PROTOCOL.md §1.4). Callers seal with
/// `MessageCryptoService.sealBlob` first, so an implementation never sees plaintext, a filename or a
/// MIME type: the relay stores bytes and a byte count, nothing else.
///
/// Progress is a plain callback rather than a stream so Core stays free of any transport type; the
/// networking module adapts its own progress object onto it.
public protocol AttachmentBlobGateway: Sendable {
    /// Uploads a sealed blob scoped to a conversation and returns the relay's id for it. `expiresAt`
    /// lets the relay purge a disappearing attachment on its own clock.
    func upload(
        _ sealedBlob: Data,
        conversationId: ConversationID,
        expiresAt: Date?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> BlobID

    /// Downloads a sealed blob. The relay only serves participants of the blob's conversation.
    func download(blobId: BlobID, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Data
}

/// SHA-256 over bytes, as lowercase hex. Core has no CryptoKit dependency on purpose (it must build
/// anywhere and never host home-grown primitives), so the digest is a port the app satisfies.
public protocol BlobHashing: Sendable {
    func sha256Hex(_ data: Data) -> String
}
