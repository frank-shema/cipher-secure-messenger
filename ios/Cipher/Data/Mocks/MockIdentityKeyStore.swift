import CipherCore
import Foundation

/// In-memory `IdentityKeyStore` for previews. It holds random 32-byte stand-ins rather than real
/// Curve25519 keys because nothing in the preview layer performs cryptography with them; the real
/// store lives in CipherCrypto and is wired in `ProductionFactories`.
actor MockIdentityKeyStore: IdentityKeyStore {
    enum Failure: Error, LocalizedError, Hashable {
        case identityExists
        case noIdentity

        var errorDescription: String? {
            switch self {
            case .identityExists: String(localized: "mock.identity.exists", defaultValue: "An identity already exists.")
            case .noIdentity: String(localized: "mock.identity.missing", defaultValue: "No identity has been created.")
            }
        }
    }

    private var keys: PublicKeyBundleUpload?

    init(existing: PublicKeyBundleUpload? = nil) {
        self.keys = existing
    }

    func hasIdentity() async throws -> Bool { keys != nil }

    func createIdentity() async throws -> PublicKeyBundleUpload {
        guard keys == nil else { throw Failure.identityExists }
        let created = PublicKeyBundleUpload(identityKey: Self.randomKey(), signingKey: Self.randomKey())
        keys = created
        return created
    }

    func publicKeys() async throws -> PublicKeyBundleUpload {
        guard let keys else { throw Failure.noIdentity }
        return keys
    }

    func deleteIdentity() async throws {
        keys = nil
    }

    private static func randomKey() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<PublicKeyBundle.keyLength).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
}
