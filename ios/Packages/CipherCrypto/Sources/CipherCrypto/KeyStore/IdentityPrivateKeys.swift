import CipherCore
import CryptoKit
import Foundation

/// This device's long-term private keys, held together so the engine always signs and agrees with
/// halves of the same identity. Kept internal to the crypto module's surface: Core never sees it, and
/// nothing here is `CustomStringConvertible`, so an accidental `print` cannot leak the bytes.
public struct IdentityPrivateKeys: Sendable {
    /// X25519 key used for the per-conversation Diffie-Hellman agreement.
    public let agreement: Curve25519.KeyAgreement.PrivateKey
    /// Ed25519 key used to sign every envelope.
    public let signing: Curve25519.Signing.PrivateKey

    public init(agreement: Curve25519.KeyAgreement.PrivateKey, signing: Curve25519.Signing.PrivateKey) {
        self.agreement = agreement
        self.signing = signing
    }

    /// Rebuilds the pair from raw 32-byte representations, refusing anything of the wrong length so a
    /// truncated Keychain item surfaces as a typed error instead of a CryptoKit crash.
    public init(rawAgreement: Data, rawSigning: Data) throws(KeyStoreError) {
        guard rawAgreement.count == PublicKeyBundle.keyLength else {
            throw .invalidKeyMaterial(expected: PublicKeyBundle.keyLength, actual: rawAgreement.count)
        }
        guard rawSigning.count == PublicKeyBundle.keyLength else {
            throw .invalidKeyMaterial(expected: PublicKeyBundle.keyLength, actual: rawSigning.count)
        }
        do {
            agreement = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawAgreement)
            signing = try Curve25519.Signing.PrivateKey(rawRepresentation: rawSigning)
        } catch {
            throw .corruptIdentity
        }
    }

    /// Fresh random identity.
    public static func generate() -> IdentityPrivateKeys {
        IdentityPrivateKeys(agreement: Curve25519.KeyAgreement.PrivateKey(), signing: Curve25519.Signing.PrivateKey())
    }

    /// The halves that are safe to publish.
    public var publicUpload: PublicKeyBundleUpload {
        PublicKeyBundleUpload(
            identityKey: agreement.publicKey.rawRepresentation,
            signingKey: signing.publicKey.rawRepresentation
        )
    }
}

/// Grants the crypto engine access to private key material. Separate from `IdentityKeyStore` so the
/// domain layer's view of the store (public halves only) stays free of anything secret, while the
/// engine, living in the same module as the stores, can be handed the same object under this protocol.
public protocol IdentityPrivateKeyProvider: Sendable {
    /// Throws `KeyStoreError.identityNotFound` when no identity exists yet.
    func privateKeys() async throws -> IdentityPrivateKeys
}
