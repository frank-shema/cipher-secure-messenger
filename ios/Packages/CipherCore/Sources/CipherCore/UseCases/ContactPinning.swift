import Foundation

/// Shared pinning rule for directory answers.
enum ContactPinning {
    /// Pins the keys for `remote.user`. Existing trust survives unless the key material differs from
    /// what was pinned, in which case the contact is flagged `keyChanged`: that flag is the only signal a
    /// person has against a relay that swaps keys, so it is never cleared silently.
    static func pin(_ remote: RemoteKeyBundle, into contacts: any ContactRepository, now: Date) async throws -> Contact {
        guard remote.keys.hasValidKeyLengths else {
            throw CipherCoreError.invalidKeyBundle(remote.user.id)
        }
        guard var contact = try await contacts.fetch(userId: remote.user.id) else {
            let fresh = Contact(user: remote.user, keys: remote.keys, trust: .unverified, presence: .unknown)
            try await contacts.upsert(fresh)
            return fresh
        }
        contact.user = remote.user
        if let previous = contact.keys, !previous.hasSameKeyMaterial(as: remote.keys) {
            contact.trust = .keyChanged(previousVersion: previous.version, at: now)
            CoreLog.useCases.warning("key material changed for user \(remote.user.id.description, privacy: .public)")
        }
        contact.keys = remote.keys
        try await contacts.upsert(contact)
        return contact
    }
}
