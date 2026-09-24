import CipherCore
import Foundation

/// `PUT /keys/me` and `POST /keys/me/rotate` body (PROTOCOL.md §1.2): raw 32-byte public keys, base64.
public struct KeyUploadRequest: Hashable, Encodable, Sendable {
    public var identityKey: Base64Data
    public var signingKey: Base64Data

    public init(_ upload: PublicKeyBundleUpload) {
        self.identityKey = Base64Data(upload.identityKey)
        self.signingKey = Base64Data(upload.signingKey)
    }
}

/// `KeyBundle` (PROTOCOL.md §1.2): who the keys belong to plus the key material.
public struct KeyBundleDTO: Hashable, Decodable, Sendable, APIResponse {
    public var userId: UserID
    public var username: String
    public var displayName: String
    public var identityKey: Base64Data
    public var signingKey: Base64Data
    public var version: Int
    public var createdAt: Int64

    public init(
        userId: UserID,
        username: String,
        displayName: String,
        identityKey: Base64Data,
        signingKey: Base64Data,
        version: Int,
        createdAt: Int64
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.identityKey = identityKey
        self.signingKey = signingKey
        self.version = version
        self.createdAt = createdAt
    }

    public var user: User {
        User(id: userId, username: username, displayName: displayName)
    }

    public var keys: PublicKeyBundle {
        PublicKeyBundle(
            userId: userId,
            identityKey: identityKey.data,
            signingKey: signingKey.data,
            version: version,
            createdAt: Date(epochMillis: createdAt)
        )
    }

    public func toDomain() -> RemoteKeyBundle {
        RemoteKeyBundle(user: user, keys: keys)
    }
}
