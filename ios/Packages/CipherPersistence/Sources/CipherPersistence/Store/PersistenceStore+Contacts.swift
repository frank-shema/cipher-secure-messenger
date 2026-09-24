import CipherCore
import Foundation
import SwiftData

extension PersistenceStore: ContactRepository {
    public func upsert(_ contact: Contact) async throws(PersistenceError) {
        try upsertContactRow(contact, now: now)
        try commit([.contact(contact.id), .conversations])
    }

    public func fetch(userId: UserID) async throws(PersistenceError) -> Contact? {
        try contactRow(userId: userId).map(ContactMapping.contact(from:))
    }

    public func fetchAll() async throws(PersistenceError) -> [Contact] {
        let descriptor = FetchDescriptor<StoredContact>(
            sortBy: [SortDescriptor(\.displayName, order: .forward), SortDescriptor(\.username, order: .forward)]
        )
        return try fetch(descriptor).map(ContactMapping.contact(from:))
    }

    public func setKeys(userId: UserID, keys: PublicKeyBundle) async throws(PersistenceError) {
        guard let row = try contactRow(userId: userId) else {
            throw .contactNotFound(userId)
        }
        ContactMapping.applyKeys(keys, to: row)
        row.updatedAt = now
        try commit([.contact(userId), .conversations])
    }

    public func setTrust(userId: UserID, trust: TrustState) async throws(PersistenceError) {
        guard let row = try contactRow(userId: userId) else {
            throw .contactNotFound(userId)
        }
        ContactMapping.applyTrust(trust, to: row)
        row.updatedAt = now
        try commit([.contact(userId), .conversations])
    }

    /// Presence for someone without a row is dropped rather than rejected: the relay broadcasts
    /// presence for any account, and a realtime handler must not fail over a stranger going online.
    public func updatePresence(userId: UserID, presence: Presence) async throws(PersistenceError) {
        guard let row = try contactRow(userId: userId) else {
            PersistenceLog.store.debug("presence ignored for unknown user \(userId.description, privacy: .public)")
            return
        }
        ContactMapping.applyPresence(presence, to: row)
        row.updatedAt = now
        try commit([.contact(userId), .conversations])
    }
}

extension PersistenceStore {
    func contactSnapshot(userId: UserID) throws(PersistenceError) -> Contact? {
        try contactRow(userId: userId).map(ContactMapping.contact(from:))
    }

    func upsertContactRow(_ contact: Contact, now: Date) throws(PersistenceError) {
        if let row = try contactRow(userId: contact.id) {
            ContactMapping.apply(contact, to: row, now: now)
        } else {
            modelContext.insert(ContactMapping.makeRow(from: contact, now: now))
        }
    }
}
