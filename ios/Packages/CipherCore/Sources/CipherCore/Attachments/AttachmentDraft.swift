import Foundation

/// Plaintext bytes plus the metadata that will travel inside the ciphertext. Built by the app after
/// it has downscaled the image and stripped its metadata; Core never inspects the bytes.
public struct AttachmentDraft: Hashable, Sendable {
    public var data: Data
    public var mimeType: String
    public var filename: String
    public var width: Int?
    public var height: Int?
    /// Small JPEG preview (≤ `AttachmentLimits.maxThumbnailBytes`) embedded in the payload so the
    /// recipient sees something before the blob downloads.
    public var thumbnail: Data?

    public init(data: Data, mimeType: String, filename: String, width: Int? = nil, height: Int? = nil, thumbnail: Data? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.filename = filename
        self.width = width
        self.height = height
        self.thumbnail = thumbnail
    }

    public var size: Int { data.count }

    public var isImage: Bool { mimeType.hasPrefix("image/") }
}

/// Size rules the relay and the protocol impose on attachments.
public enum AttachmentLimits {
    /// Relay limit on one uploaded blob (PROTOCOL.md §1.4).
    public static let maxBlobBytes = 25 * 1_024 * 1_024
    /// `ChaChaPoly` combined form adds a 12-byte nonce and a 16-byte tag around the plaintext.
    public static let sealOverheadBytes = 28
    /// Largest plaintext that still seals under the relay limit.
    public static let maxPlaintextBytes = maxBlobBytes - sealOverheadBytes
    /// Thumbnail ceiling from PROTOCOL.md §3 so a payload stays far below the 256 KiB envelope cap.
    public static let maxThumbnailBytes = 24 * 1_024
    /// Longest side the app downscales photos to before sealing.
    public static let maxImageDimension = 2_048
    /// Longest side of the embedded thumbnail.
    public static let thumbnailDimension = 320
}
