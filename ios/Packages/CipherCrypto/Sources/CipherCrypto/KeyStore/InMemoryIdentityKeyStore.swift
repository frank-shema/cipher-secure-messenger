import CipherCore
import Foundation

/// Identity store that lives only in process memory. Used by previews, the DEBUG demo companion and
/// integration tests, where touching the real Keychain would be slow, need entitlements, or leave
/// keys behind on a developer's machine.
public actor InMemoryIdentityKeyStore: IdentityKeyStore, IdentityPrivateKeyProvider {
    private var keys: IdentityPrivateKeys?

    /// Starts empty, or pre-seeded with a known pair (e.g. to give both sides of a preview a stable identity).
    public init(keys: IdentityPrivateKeys? = nil) {
        self.keys = keys
    }

    public func hasIdentity() async throws -> Bool {
        keys != nil
    }

    public func createIdentity() async throws -> PublicKeyBundleUpload {
        guard keys == nil else { throw KeyStoreError.identityAlreadyExists }
        let generated = IdentityPrivateKeys.generate()
        keys = generated
        return generated.publicUpload
    }

    public func publicKeys() async throws -> PublicKeyBundleUpload {
        guard let keys else { throw KeyStoreError.identityNotFound }
        return keys.publicUpload
    }

    public func deleteIdentity() async throws {
        keys = nil
    }

    public func privateKeys() async throws -> IdentityPrivateKeys {
        guard let keys else { throw KeyStoreError.identityNotFound }
        return keys
    }
}
