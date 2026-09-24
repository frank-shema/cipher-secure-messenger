import CipherCore
import CipherCrypto
import CipherDesign
import Foundation

/// Preview wiring for the verification screens on the in-memory messaging fakes. Each call builds an
/// isolated store so one preview cannot verify a contact in another.
@MainActor
enum VerifyPreviews {
    enum Scenario {
        case unverified
        case verified
        case keyChanged

        @MainActor var contact: Contact {
            let contacts = MessagingFixtures.contacts(now: PreviewMessaging.frozenNow)
            switch self {
            case .unverified: return contacts[3]
            case .verified: return contacts[0]
            case .keyChanged: return contacts[2]
            }
        }
    }

    static func dependencies(store: PreviewMessagingStore) -> VerifyDependencies {
        let mine = Fixtures.keyBundle(for: MessagingFixtures.me)
        return VerifyDependencies(
            currentUser: MessagingFixtures.me,
            contacts: store,
            identityKeys: MockIdentityKeyStore(existing: PublicKeyBundleUpload(identityKey: mine.identityKey, signingKey: mine.signingKey)),
            verify: PreviewContactVerifier(store: store)
        )
    }

    static func viewModel(for scenario: Scenario) -> VerifyContactViewModel {
        let store = PreviewMessagingStore.seeded(now: PreviewMessaging.frozenNow)
        return VerifyContactViewModel(userId: scenario.contact.id, dependencies: dependencies(store: store))
    }

    static var sampleFingerprint: SafetyFingerprint {
        SafetyFingerprintGenerator.generate(
            mine: Fixtures.keyBundle(for: MessagingFixtures.me),
            theirs: Fixtures.keyBundle(for: Fixtures.bob)
        )
    }

    static var sampleSafetyNumber: SafetyNumber {
        (try? SafetyNumberFormatter().format(sampleFingerprint)) ?? SafetyNumber(blocks: Array(repeating: "00000", count: 16))
    }

    static var samplePayload: String {
        QRPayload(bundle: Fixtures.keyBundle(for: MessagingFixtures.me)).encoded
    }

    static var sampleKeyChange: KeyChangeInfo {
        KeyChangeInfo(
            contactName: "Mara",
            previousVersion: 1,
            currentVersion: 2,
            currentKeysPublishedAt: PreviewMessaging.frozenNow.addingTimeInterval(-3_600),
            changedAt: PreviewMessaging.frozenNow.addingTimeInterval(-3_600)
        )
    }
}
