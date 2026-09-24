import Foundation

/// A user's published public keys. `identityKey` is a raw 32-byte X25519 key used for key agreement;
/// `signingKey` a raw 32-byte Ed25519 key used to authenticate every envelope. The relay stores
/// exactly what was uploaded, so the client must validate lengths itself before pinning.
public struct PublicKeyBundle: Hashable, Codable, Sendable {
    /// Raw key length CryptoKit expects for both Curve25519 key kinds.
    public static let keyLength = 32

    public var userId: UserID
    public var identityKey: Data
    public var signingKey: Data
    public var version: Int
    public var createdAt: Date

    public init(userId: UserID, identityKey: Data, signingKey: Data, version: Int, createdAt: Date) {
        self.userId = userId
        self.identityKey = identityKey
        self.signingKey = signingKey
        self.version = version
        self.createdAt = createdAt
    }

    /// Checked before a bundle is pinned: a truncated or padded key from a buggy directory response
    /// must never become the identity every later message is verified against.
    public var hasValidKeyLengths: Bool {
        identityKey.count == Self.keyLength && signingKey.count == Self.keyLength
    }

    /// "Did the keys change?" compares key material only; `version`/`createdAt` are bookkeeping.
    public func hasSameKeyMaterial(as other: PublicKeyBundle) -> Bool {
        identityKey == other.identityKey && signingKey == other.signingKey
    }
}

/// The public halves the client uploads (`PUT /keys/me`, `POST /keys/me/rotate`). Private material
/// never leaves the identity store, which is why this type cannot even represent it.
public struct PublicKeyBundleUpload: Hashable, Codable, Sendable {
    public var identityKey: Data
    public var signingKey: Data

    public init(identityKey: Data, signingKey: Data) {
        self.identityKey = identityKey
        self.signingKey = signingKey
    }
}

/// A directory answer: who the keys belong to plus the keys. Returned by lookups and fetches because
/// the relay's `KeyBundle` carries `username`/`displayName` alongside the key material.
public struct RemoteKeyBundle: Hashable, Sendable {
    public var user: User
    public var keys: PublicKeyBundle

    public init(user: User, keys: PublicKeyBundle) {
        self.user = user
        self.keys = keys
    }
}
