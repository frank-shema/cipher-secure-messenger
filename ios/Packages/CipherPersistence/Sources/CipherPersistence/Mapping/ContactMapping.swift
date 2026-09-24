import CipherCore
import Foundation

/// Translates between the domain `Contact` and its row. Trust is flattened into a discriminator plus
/// two payload columns so "needs attention" can be queried without decoding anything.
enum ContactMapping {
    enum TrustColumn: String {
        case unverified
        case verified
        case keyChanged
    }

    static func makeRow(from contact: Contact, now: Date) -> StoredContact {
        let row = StoredContact(
            userId: contact.id.uuid,
            username: contact.user.username,
            displayName: contact.user.displayName,
            identityKey: nil,
            signingKey: nil,
            keyVersion: nil,
            keysCreatedAt: nil,
            trustRaw: TrustColumn.unverified.rawValue,
            trustAt: nil,
            trustPreviousVersion: nil,
            isOnline: contact.presence.online,
            lastSeenAt: contact.presence.lastSeenAt,
            updatedAt: now
        )
        apply(contact, to: row, now: now)
        return row
    }

    static func apply(_ contact: Contact, to row: StoredContact, now: Date) {
        row.username = contact.user.username
        row.displayName = contact.user.displayName
        applyKeys(contact.keys, to: row)
        applyTrust(contact.trust, to: row)
        applyPresence(contact.presence, to: row)
        row.updatedAt = now
    }

    /// Pinned keys are only ever replaced, never cleared: losing the pinned material would silently
    /// turn a `keyChanged` warning into a fresh, trusting `unverified` on the next directory answer.
    static func applyKeys(_ keys: PublicKeyBundle?, to row: StoredContact) {
        guard let keys else { return }
        row.identityKey = keys.identityKey
        row.signingKey = keys.signingKey
        row.keyVersion = keys.version
        row.keysCreatedAt = keys.createdAt
    }

    static func applyTrust(_ trust: TrustState, to row: StoredContact) {
        switch trust {
        case .unverified:
            row.trustRaw = TrustColumn.unverified.rawValue
            row.trustAt = nil
            row.trustPreviousVersion = nil
        case .verified(let date):
            row.trustRaw = TrustColumn.verified.rawValue
            row.trustAt = date
            row.trustPreviousVersion = nil
        case .keyChanged(let previousVersion, let date):
            row.trustRaw = TrustColumn.keyChanged.rawValue
            row.trustAt = date
            row.trustPreviousVersion = previousVersion
        }
    }

    static func applyPresence(_ presence: Presence, to row: StoredContact) {
        row.isOnline = presence.online
        row.lastSeenAt = presence.lastSeenAt ?? row.lastSeenAt
    }

    static func contact(from row: StoredContact) -> Contact {
        Contact(
            user: User(id: UserID(row.userId), username: row.username, displayName: row.displayName),
            keys: keys(from: row),
            trust: trust(from: row),
            presence: Presence(online: row.isOnline, lastSeenAt: row.lastSeenAt)
        )
    }

    private static func keys(from row: StoredContact) -> PublicKeyBundle? {
        guard let identityKey = row.identityKey,
              let signingKey = row.signingKey,
              let version = row.keyVersion,
              let createdAt = row.keysCreatedAt else {
            return nil
        }
        return PublicKeyBundle(
            userId: UserID(row.userId),
            identityKey: identityKey,
            signingKey: signingKey,
            version: version,
            createdAt: createdAt
        )
    }

    /// An unknown discriminator (from a newer build) degrades to `unverified`: the safe direction,
    /// since it asks the person to look again rather than granting trust that was never recorded.
    private static func trust(from row: StoredContact) -> TrustState {
        switch TrustColumn(rawValue: row.trustRaw) {
        case .verified:
            guard let at = row.trustAt else { return .unverified }
            return .verified(at: at)
        case .keyChanged:
            guard let at = row.trustAt, let previous = row.trustPreviousVersion else { return .unverified }
            return .keyChanged(previousVersion: previous, at: at)
        case .unverified, .none:
            return .unverified
        }
    }
}
