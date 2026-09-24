import Foundation

/// Reference to an encrypted blob plus everything needed to decrypt and render it. All of this lives
/// inside the ciphertext: the relay sees only an opaque blob id and byte count.
public struct Attachment: Hashable, Sendable {
    public var blobId: BlobID
    /// 32-byte symmetric key the blob was sealed with.
    public var key: Data
    /// Hex SHA-256 over the encrypted blob, checked before decryption.
    public var sha256: String
    public var mimeType: String
    public var filename: String
    public var size: Int
    public var width: Int?
    public var height: Int?
    /// Small JPEG preview (≤ 24 KiB) so the UI can show something before the blob downloads.
    public var thumbnail: Data?

    public init(
        blobId: BlobID,
        key: Data,
        sha256: String,
        mimeType: String,
        filename: String,
        size: Int,
        width: Int? = nil,
        height: Int? = nil,
        thumbnail: Data? = nil
    ) {
        self.blobId = blobId
        self.key = key
        self.sha256 = sha256
        self.mimeType = mimeType
        self.filename = filename
        self.size = size
        self.width = width
        self.height = height
        self.thumbnail = thumbnail
    }
}

extension Attachment: Codable {
    private enum CodingKeys: String, CodingKey {
        case blobId
        case key
        case sha256
        case mimeType
        case filename
        case size
        case width
        case height
        case thumbnail
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blobId = try container.decode(BlobID.self, forKey: .blobId)
        key = try container.decodeBase64(forKey: .key)
        sha256 = try container.decode(String.self, forKey: .sha256)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        filename = try container.decode(String.self, forKey: .filename)
        size = try container.decode(Int.self, forKey: .size)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        thumbnail = try container.decodeBase64IfPresent(forKey: .thumbnail)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blobId, forKey: .blobId)
        try container.encodeBase64(key, forKey: .key)
        try container.encode(sha256, forKey: .sha256)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(filename, forKey: .filename)
        try container.encode(size, forKey: .size)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encodeBase64(thumbnail, forKey: .thumbnail)
    }
}
