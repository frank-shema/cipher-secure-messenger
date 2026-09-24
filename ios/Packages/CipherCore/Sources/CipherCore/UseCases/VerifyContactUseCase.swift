import Foundation

/// Records that the person compared safety fingerprints with this contact out of band.
public struct VerifyContactUseCase: Sendable {
    private let contacts: any ContactRepository
    private let clock: any Clock

    public init(contacts: any ContactRepository, clock: any Clock = SystemClock()) {
        self.contacts = contacts
        self.clock = clock
    }

    public func execute(userId: UserID) async throws -> Contact {
        try await contacts.setTrust(userId: userId, trust: .verified(at: clock.now()))
        guard let contact = try await contacts.fetch(userId: userId) else {
            throw CipherCoreError.contactNotFound(userId)
        }
        CoreLog.useCases.info("contact \(userId.description, privacy: .public) verified")
        return contact
    }
}
