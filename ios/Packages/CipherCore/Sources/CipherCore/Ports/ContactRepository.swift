import Foundation

public protocol ContactRepository: Sendable {
    func upsert(_ contact: Contact) async throws
    func fetch(userId: UserID) async throws -> Contact?
    func fetchAll() async throws -> [Contact]
    /// Pins new key material; callers decide the trust consequence separately.
    func setKeys(userId: UserID, keys: PublicKeyBundle) async throws
    func setTrust(userId: UserID, trust: TrustState) async throws
    func updatePresence(userId: UserID, presence: Presence) async throws
    /// Emits the contact on subscription (if it exists) and after every change.
    func observe(userId: UserID) async -> AsyncStream<Contact>
}
