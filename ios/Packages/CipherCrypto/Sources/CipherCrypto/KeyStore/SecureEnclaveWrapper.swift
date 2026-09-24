import CryptoKit
import Foundation
import Security

/// Wraps raw private keys with a key that never leaves the Secure Enclave.
///
/// Curve25519 keys cannot live inside the enclave (it only speaks P-256), so the next best thing is to
/// make the stored bytes useless without it: each raw key is AES-GCM encrypted under a key agreed
/// between an ephemeral P-256 key and the enclave's own P-256 key-agreement key (ECIES style). A
/// Keychain dump from a jailbroken device or a forensic backup therefore yields only ciphertext that
/// this specific chip can open. Where no enclave exists (Simulator, some Macs) the wrapper reports
/// itself unavailable and the store transparently keeps raw keys.
///
/// Blob layout: `ephemeralPublicKey (65 bytes, X9.63) ‖ AES.GCM.SealedBox.combined`.
public struct SecureEnclaveWrapper {
    /// Length of an uncompressed X9.63 P-256 public key.
    private static let ephemeralKeyLength = 65
    private static let wrapInfo = Data("cipher/v1/se-wrap".utf8)

    private let enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey

    /// True when this device has an enclave the current process may use.
    public static var isAvailable: Bool {
        SecureEnclave.isAvailable
    }

    /// Restores a wrapper from the opaque representation `dataRepresentation` returned earlier. The
    /// representation is not the key: it is an enclave-encrypted handle that only this chip can use.
    public init(dataRepresentation: Data) throws(KeyStoreError) {
        guard Self.isAvailable else { throw .secureEnclaveUnavailable }
        do {
            enclaveKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: dataRepresentation)
        } catch {
            CryptoLog.keyStore.error("Secure Enclave wrapping key could not be restored")
            throw .secureEnclaveUnavailable
        }
    }

    /// Creates a brand-new enclave key, usable only while the device is unlocked and never exportable.
    public static func create() throws(KeyStoreError) -> SecureEnclaveWrapper {
        guard isAvailable else { throw .secureEnclaveUnavailable }
        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            &accessError
        ) else {
            CryptoLog.keyStore.error("Secure Enclave access control could not be created")
            throw .secureEnclaveUnavailable
        }
        do {
            let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: accessControl)
            return SecureEnclaveWrapper(enclaveKey: key)
        } catch {
            CryptoLog.keyStore.error("Secure Enclave key generation failed")
            throw .secureEnclaveUnavailable
        }
    }

    private init(enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey) {
        self.enclaveKey = enclaveKey
    }

    /// Opaque handle to persist alongside the wrapped keys.
    public var dataRepresentation: Data {
        enclaveKey.dataRepresentation
    }

    /// Encrypts `raw` so only this enclave can recover it. A fresh ephemeral key per call means two
    /// wraps of the same bytes never look alike.
    public func wrap(_ raw: Data) throws(KeyStoreError) -> Data {
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let ephemeralPublic = ephemeral.publicKey.x963Representation
        do {
            let shared = try ephemeral.sharedSecretFromKeyAgreement(with: enclaveKey.publicKey)
            let wrappingKey = Self.deriveWrappingKey(from: shared)
            let sealed = try AES.GCM.seal(raw, using: wrappingKey, authenticating: ephemeralPublic)
            guard let combined = sealed.combined else { throw KeyStoreError.unwrapFailed }
            return ephemeralPublic + combined
        } catch let error as KeyStoreError {
            throw error
        } catch {
            CryptoLog.keyStore.error("Secure Enclave wrap failed")
            throw .secureEnclaveUnavailable
        }
    }

    /// Recovers the raw bytes; any alteration of the blob fails authentication.
    public func unwrap(_ blob: Data) throws(KeyStoreError) -> Data {
        guard blob.count > Self.ephemeralKeyLength else { throw .unwrapFailed }
        let ephemeralPublic = blob.prefix(Self.ephemeralKeyLength)
        let combined = blob.dropFirst(Self.ephemeralKeyLength)
        do {
            let peer = try P256.KeyAgreement.PublicKey(x963Representation: ephemeralPublic)
            let shared = try enclaveKey.sharedSecretFromKeyAgreement(with: peer)
            let wrappingKey = Self.deriveWrappingKey(from: shared)
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: wrappingKey, authenticating: ephemeralPublic)
        } catch {
            CryptoLog.keyStore.error("Secure Enclave unwrap failed")
            throw .unwrapFailed
        }
    }

    private static func deriveWrappingKey(from shared: SharedSecret) -> SymmetricKey {
        shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: wrapInfo, outputByteCount: 32)
    }
}
