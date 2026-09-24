import Foundation
import SwiftData

/// A peer plus the keys pinned for them. Keys are optional because a contact can exist before the
/// directory answered; trust is flattened into three columns so it can be queried without decoding.
@Model
final class StoredContact {
    @Attribute(.unique) var userId: UUID
    var username: String
    var displayName: String
    /// Raw 32-byte X25519 public key, once pinned.
    var identityKey: Data?
    /// Raw 32-byte Ed25519 public key, once pinned.
    var signingKey: Data?
    var keyVersion: Int?
    var keysCreatedAt: Date?
    /// `TrustState` discriminator: `unverified`, `verified` or `keyChanged`.
    var trustRaw: String
    var trustAt: Date?
    var trustPreviousVersion: Int?
    var isOnline: Bool
    var lastSeenAt: Date?
    var updatedAt: Date

    init(
        userId: UUID,
        username: String,
        displayName: String,
        identityKey: Data?,
        signingKey: Data?,
        keyVersion: Int?,
        keysCreatedAt: Date?,
        trustRaw: String,
        trustAt: Date?,
        trustPreviousVersion: Int?,
        isOnline: Bool,
        lastSeenAt: Date?,
        updatedAt: Date
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.identityKey = identityKey
        self.signingKey = signingKey
        self.keyVersion = keyVersion
        self.keysCreatedAt = keysCreatedAt
        self.trustRaw = trustRaw
        self.trustAt = trustAt
        self.trustPreviousVersion = trustPreviousVersion
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
        self.updatedAt = updatedAt
    }
}
