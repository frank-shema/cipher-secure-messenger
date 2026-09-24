import CipherCore
import CipherCrypto
import Foundation

/// Everything the verification screen needs, expressed as Core ports so previews can run it on the
/// in-memory fakes and production on the account's `MessagingStack`.
///
/// `fingerprint` is a function rather than a `MessageCryptoService` because the fingerprint is the
/// only crypto operation this feature performs and the generator is pure: taking the whole service
/// would drag the identity provider into every preview for no gain.
struct VerifyDependencies: Sendable {
    let currentUser: User
    let contacts: any ContactRepository
    let identityKeys: any IdentityKeyStore
    let verify: any ContactVerifying
    let clock: any Clock
    let fingerprint: @Sendable (_ mine: PublicKeyBundle, _ theirs: PublicKeyBundle) -> SafetyFingerprint

    init(
        currentUser: User,
        contacts: any ContactRepository,
        identityKeys: any IdentityKeyStore,
        verify: any ContactVerifying,
        clock: any Clock = SystemClock(),
        fingerprint: @escaping @Sendable (PublicKeyBundle, PublicKeyBundle) -> SafetyFingerprint = SafetyFingerprintGenerator.generate
    ) {
        self.currentUser = currentUser
        self.contacts = contacts
        self.identityKeys = identityKeys
        self.verify = verify
        self.clock = clock
        self.fingerprint = fingerprint
    }
}

extension VerifyDependencies {
    /// Production wiring: the account's stack supplies the contact store, the crypto engine and the
    /// verify use case; the identity store comes from the container because it outlives any session.
    init(stack: MessagingStack, identityKeys: any IdentityKeyStore) {
        let crypto = stack.crypto
        self.init(
            currentUser: stack.account,
            contacts: stack.contacts,
            identityKeys: identityKeys,
            verify: stack.verifyContact,
            clock: stack.clock,
            fingerprint: { mine, theirs in crypto.fingerprint(mine: mine, theirs: theirs) }
        )
    }
}

/// What a `TrustState.keyChanged` contact looks like to the person: which version was pinned, which
/// the directory now serves and when the change was noticed. Presented by `KeyChangeReviewView`.
struct KeyChangeInfo: Hashable, Sendable {
    var contactName: String
    var previousVersion: Int
    var currentVersion: Int?
    var currentKeysPublishedAt: Date?
    var changedAt: Date

    /// `nil` unless the contact's trust is `.keyChanged`, so the review card can never appear for a
    /// contact whose keys are stable.
    init?(contact: Contact) {
        guard case .keyChanged(let previousVersion, let changedAt) = contact.trust else { return nil }
        self.contactName = contact.user.displayName
        self.previousVersion = previousVersion
        self.currentVersion = contact.keys?.version
        self.currentKeysPublishedAt = contact.keys?.createdAt
        self.changedAt = changedAt
    }

    init(contactName: String, previousVersion: Int, currentVersion: Int?, currentKeysPublishedAt: Date?, changedAt: Date) {
        self.contactName = contactName
        self.previousVersion = previousVersion
        self.currentVersion = currentVersion
        self.currentKeysPublishedAt = currentKeysPublishedAt
        self.changedAt = changedAt
    }
}
