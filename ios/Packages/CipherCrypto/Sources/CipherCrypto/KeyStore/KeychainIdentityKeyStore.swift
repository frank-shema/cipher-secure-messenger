import CipherCore
import CryptoKit
import Foundation

/// Keeps this device's Curve25519 private keys in the data-protection Keychain, optionally wrapped by
/// the Secure Enclave. An actor so "check, then create" is atomic: two concurrent bootstrap calls can
/// never generate two identities and publish the wrong one.
///
/// The service name is a parameter so separate identities (the user's, the DEBUG demo companion's)
/// live under separate services and cannot collide.
public actor KeychainIdentityKeyStore: IdentityKeyStore, IdentityPrivateKeyProvider {
    private enum Account {
        static let agreement = "identity.x25519"
        static let signing = "identity.ed25519"
        static let enclaveKey = "identity.secure-enclave-wrapping-key"
    }

    /// First byte of every stored blob, so a key wrapped on one device is never misread as raw.
    private enum Format: UInt8 {
        case raw = 0x01
        case secureEnclave = 0x02
    }

    private let client: KeychainClient
    private let useSecureEnclave: Bool
    private var cached: IdentityPrivateKeys?

    /// - Parameters:
    ///   - service: Keychain service name; defaults to the app identity service.
    ///   - useSecureEnclave: opt out (e.g. in UI tests) even where an enclave exists.
    public init(service: String = CipherCrypto.defaultKeychainService, useSecureEnclave: Bool = true) {
        self.client = KeychainClient(service: service)
        self.useSecureEnclave = useSecureEnclave && SecureEnclaveWrapper.isAvailable
    }

    public func hasIdentity() async throws -> Bool {
        if cached != nil { return true }
        let agreement = try client.read(account: Account.agreement)
        let signing = try client.read(account: Account.signing)
        return agreement != nil && signing != nil
    }

    public func createIdentity() async throws -> PublicKeyBundleUpload {
        try removeOrphanedHalf()
        if try await hasIdentity() { throw KeyStoreError.identityAlreadyExists }

        let generated = IdentityPrivateKeys.generate()
        try store(generated)
        cached = generated
        CryptoLog.keyStore.info("Identity created (secureEnclave: \(self.useSecureEnclave, privacy: .public))")
        return generated.publicUpload
    }

    public func publicKeys() async throws -> PublicKeyBundleUpload {
        try await privateKeys().publicUpload
    }

    public func deleteIdentity() async throws {
        cached = nil
        try client.delete(account: Account.agreement)
        try client.delete(account: Account.signing)
        try client.delete(account: Account.enclaveKey)
        CryptoLog.keyStore.notice("Identity deleted")
    }

    public func privateKeys() async throws -> IdentityPrivateKeys {
        if let cached { return cached }
        guard let agreementBlob = try client.read(account: Account.agreement),
              let signingBlob = try client.read(account: Account.signing) else {
            throw KeyStoreError.identityNotFound
        }
        let keys = try IdentityPrivateKeys(rawAgreement: unpack(agreementBlob), rawSigning: unpack(signingBlob))
        cached = keys
        return keys
    }

    // MARK: - Storage

    /// Writes both halves; if the second write fails the first is rolled back so the store never holds
    /// a half identity that `hasIdentity()` would report as present.
    private func store(_ keys: IdentityPrivateKeys) throws(KeyStoreError) {
        let wrapper = try loadOrCreateWrapper()
        try client.add(account: Account.agreement, data: pack(keys.agreement.rawRepresentation, wrapper: wrapper))
        do {
            try client.add(account: Account.signing, data: pack(keys.signing.rawRepresentation, wrapper: wrapper))
        } catch {
            try client.delete(account: Account.agreement)
            throw error
        }
    }

    /// A lone half can only come from an interrupted create; it is useless and would block bootstrap forever.
    private func removeOrphanedHalf() throws(KeyStoreError) {
        let hasAgreement = try client.read(account: Account.agreement) != nil
        let hasSigning = try client.read(account: Account.signing) != nil
        guard hasAgreement != hasSigning else { return }
        CryptoLog.keyStore.fault("Removing orphaned identity half")
        try client.delete(account: Account.agreement)
        try client.delete(account: Account.signing)
    }

    private func loadOrCreateWrapper() throws(KeyStoreError) -> SecureEnclaveWrapper? {
        guard useSecureEnclave else { return nil }
        if let representation = try client.read(account: Account.enclaveKey) {
            return try SecureEnclaveWrapper(dataRepresentation: representation)
        }
        let wrapper = try SecureEnclaveWrapper.create()
        try client.add(account: Account.enclaveKey, data: wrapper.dataRepresentation)
        return wrapper
    }

    private func pack(_ raw: Data, wrapper: SecureEnclaveWrapper?) throws(KeyStoreError) -> Data {
        guard let wrapper else { return Data([Format.raw.rawValue]) + raw }
        return try Data([Format.secureEnclave.rawValue]) + wrapper.wrap(raw)
    }

    private func unpack(_ blob: Data) throws(KeyStoreError) -> Data {
        guard let first = blob.first, let format = Format(rawValue: first) else { throw .corruptIdentity }
        let body = blob.dropFirst()
        switch format {
        case .raw:
            return Data(body)
        case .secureEnclave:
            guard let representation = try client.read(account: Account.enclaveKey) else {
                throw .secureEnclaveUnavailable
            }
            let wrapper = try SecureEnclaveWrapper(dataRepresentation: representation)
            return try wrapper.unwrap(Data(body))
        }
    }
}
