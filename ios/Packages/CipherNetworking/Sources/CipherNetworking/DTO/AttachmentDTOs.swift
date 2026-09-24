import CipherCore
import Foundation

/// `BlobDescriptor` (PROTOCOL.md §1.4): what the relay knows about an uploaded blob, which is nothing
/// but its size and clocks.
public struct BlobDescriptorDTO: Hashable, Decodable, Sendable, APIResponse {
    public var blobId: BlobID
    public var size: Int64
    public var createdAt: Int64
    public var expiresAt: Int64?

    public init(blobId: BlobID, size: Int64, createdAt: Int64, expiresAt: Int64?) {
        self.blobId = blobId
        self.size = size
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public func toDomain() -> BlobDescriptor {
        BlobDescriptor(
            blobId: blobId,
            size: Int(clamping: size),
            createdAt: Date(epochMillis: createdAt),
            expiresAt: expiresAt.map { Date(epochMillis: $0) }
        )
    }
}
