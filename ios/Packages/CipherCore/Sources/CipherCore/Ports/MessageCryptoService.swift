import Foundation

/// Failures of the envelope cryptography. Each maps to a `TamperReason` so a message that cannot be
/// opened is still shown, with an explanation, rather than dropped.
public enum CryptoError: Error, LocalizedError, Hashable, Sendable {
    /// Ed25519 verification over `aad ‖ ciphertext` failed against the pinned signing key.
    case invalidSignature
    /// AEAD open failed: wrong key, altered ciphertext or altered associated data.
    case decryptionFailed
    /// Decrypted bytes are not a valid `MessagePayload`.
    case malformedPayload
    /// A raw key had the wrong byte length; the bundle cannot be used at all.
    case keyLength(expected: Int, actual: Int)
    /// This device's private keys are missing or unreadable.
    case identityUnavailable

    public var tamperReason: TamperReason {
        switch self {
        case .invalidSignature: .invalidSignature
        case .decryptionFailed, .identityUnavailable: .decryptionFailed
        case .malformedPayload: .malformedPayload
        case .keyLength: .unknownSender
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidSignature:
            CoreStrings.localized("error.crypto.invalidSignature", default: "The message signature could not be verified.")
        case .decryptionFailed:
            CoreStrings.localized("error.crypto.decryptionFailed", default: "The message could not be decrypted.")
        case .malformedPayload:
            CoreStrings.localized("error.crypto.malformedPayload", default: "The decrypted message is malformed.")
        case .keyLength:
            CoreStrings.localized("error.crypto.keyLength", default: "A contact key has an invalid length.")
        case .identityUnavailable:
            CoreStrings.localized("error.crypto.identityUnavailable", default: "Your identity keys are unavailable.")
        }
    }
}

/// Eight emoji plus the hex digest they were derived from (PROTOCOL.md §4), identical on both devices.
public struct SafetyFingerprint: Hashable, Sendable {
    public var emoji: [String]
    public var hex: String

    public init(emoji: [String], hex: String) {
        self.emoji = emoji
        self.hex = hex
    }
}

/// PROTOCOL.md §4 envelope cryptography, implemented in CipherCrypto. Core defines only the contract
/// so use cases and tests never touch CryptoKit.
public protocol MessageCryptoService: Sendable {
    /// Seals `payload` for `recipient`. The header supplies the message id and every AAD field, so the
    /// returned envelope and its authentication tag are guaranteed to describe the same routing.
    func seal(payload: MessagePayload, for recipient: PublicKeyBundle, header: EnvelopeHeader) async throws(CryptoError) -> Envelope

    /// Verifies the signature FIRST, then derives the key and opens. `peer` is the other participant;
    /// when `envelope.senderId == myUserId` (own history during sync) the signature is checked against
    /// this device's signing key instead, and the message key still derives from the sender id.
    func open(_ envelope: Envelope, peer: PublicKeyBundle, myUserId: UserID) async throws(CryptoError) -> MessagePayload

    /// Fresh 32-byte random key for one attachment.
    func attachmentKey() -> Data
    /// `ChaChaPoly.seal(data, key)` combined form (`nonce ‖ ciphertext ‖ tag`).
    func sealBlob(_ data: Data, key: Data) throws(CryptoError) -> Data
    func openBlob(_ data: Data, key: Data) throws(CryptoError) -> Data

    /// Symmetric: both participants compute the same value from the same two bundles.
    func fingerprint(mine: PublicKeyBundle, theirs: PublicKeyBundle) -> SafetyFingerprint
}
