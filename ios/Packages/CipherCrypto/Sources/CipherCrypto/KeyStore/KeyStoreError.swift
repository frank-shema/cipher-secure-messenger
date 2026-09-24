import Foundation

/// Failures of the identity key store. Keychain `OSStatus` codes are wrapped rather than surfaced so
/// callers can react to the few cases that matter (locked device, missing identity) without knowing
/// Security.framework, and so the raw status still reaches the logs for diagnosis.
public enum KeyStoreError: Error, LocalizedError, Hashable, Sendable {
    /// `createIdentity()` was called while an identity exists. Overwriting is refused by design: every
    /// contact has pinned these keys, so replacing them silently would break every conversation.
    case identityAlreadyExists
    /// No identity has been created on this device yet.
    case identityNotFound
    /// Stored bytes are not a valid Curve25519 key, or only one half of the pair survived.
    case corruptIdentity
    /// The Keychain refused because the device is locked; retry once it is unlocked.
    case deviceLocked
    /// The app lacks the entitlement or the item belongs to another access group.
    case accessDenied(status: Int32)
    /// Any other Security.framework failure, with its `OSStatus`.
    case keychain(status: Int32)
    /// A key was wrapped by the Secure Enclave but the enclave (or its wrapping key) is now unavailable.
    case secureEnclaveUnavailable
    /// Unwrapping a Secure Enclave protected key failed; the blob was altered or belongs to another key.
    case unwrapFailed
    /// Key bytes handed to the store had the wrong length.
    case invalidKeyMaterial(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .identityAlreadyExists:
            CryptoStrings.localized("error.keystore.identityAlreadyExists", default: "An identity already exists on this device.")
        case .identityNotFound:
            CryptoStrings.localized("error.keystore.identityNotFound", default: "No identity keys were found on this device.")
        case .corruptIdentity:
            CryptoStrings.localized("error.keystore.corruptIdentity", default: "The stored identity keys are damaged.")
        case .deviceLocked:
            CryptoStrings.localized("error.keystore.deviceLocked", default: "Unlock your device to access your keys.")
        case .accessDenied:
            CryptoStrings.localized("error.keystore.accessDenied", default: "Cipher is not allowed to access the Keychain.")
        case .keychain:
            CryptoStrings.localized("error.keystore.keychain", default: "The Keychain returned an unexpected error.")
        case .secureEnclaveUnavailable:
            CryptoStrings.localized("error.keystore.secureEnclaveUnavailable", default: "The Secure Enclave is unavailable.")
        case .unwrapFailed:
            CryptoStrings.localized("error.keystore.unwrapFailed", default: "Your keys could not be unlocked by the Secure Enclave.")
        case .invalidKeyMaterial:
            CryptoStrings.localized("error.keystore.invalidKeyMaterial", default: "The key material has an invalid length.")
        }
    }

    /// Maps a Security.framework status to the case callers can act on.
    static func fromStatus(_ status: OSStatus) -> KeyStoreError {
        switch status {
        case errSecInteractionNotAllowed:
            return .deviceLocked
        case errSecAuthFailed, errSecMissingEntitlement:
            return .accessDenied(status: status)
        case errSecDuplicateItem:
            return .identityAlreadyExists
        default:
            return .keychain(status: status)
        }
    }
}
