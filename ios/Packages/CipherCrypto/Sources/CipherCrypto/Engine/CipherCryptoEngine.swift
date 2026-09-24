import CipherCore
import CryptoKit
import Foundation

/// PROTOCOL.md §4 envelope cryptography on Apple CryptoKit. An actor so every seal and open runs on
/// the cooperative pool rather than wherever the caller happens to be (never the main actor), and so
/// the private keys loaded from the store are read under one isolation domain.
///
/// Order of operations on receive is deliberate: the signature is verified against the pinned key
/// before any key derivation or decryption, so an envelope from an impostor is rejected without the
/// AEAD ever seeing it. This is what makes "tampered" a trustworthy verdict in the UI.
public actor CipherCryptoEngine: MessageCryptoService {
    private let keyProvider: any IdentityPrivateKeyProvider
    private let codec = MessagePayloadCodec()

    /// - Parameter keyProvider: the identity store holding this device's private keys
    ///   (`KeychainIdentityKeyStore` in the app, `InMemoryIdentityKeyStore` in previews).
    public init(keyProvider: any IdentityPrivateKeyProvider) {
        self.keyProvider = keyProvider
    }

    // MARK: - Envelopes

    public func seal(
        payload: MessagePayload,
        for recipient: PublicKeyBundle,
        header: EnvelopeHeader
    ) async throws(CryptoError) -> Envelope {
        try Self.validateLengths(recipient)
        let keys = try await loadKeys()
        let version = CipherCore.protocolVersion

        let plaintext: Data
        do {
            plaintext = try codec.encode(payload)
        } catch {
            throw .malformedPayload
        }

        let aad = AssociatedData.canonical(for: header, version: version)
        let context = DerivationContext(
            conversationId: header.conversationId,
            senderId: header.senderId,
            counter: header.counter,
            version: version
        )
        let messageKey = try Self.messageKey(mine: keys.agreement, theirIdentityKey: recipient.identityKey, context: context)

        let ciphertext: Data
        do {
            ciphertext = try ChaChaPoly.seal(plaintext, using: messageKey, authenticating: aad).combined
        } catch {
            CryptoLog.engine.error("Seal failed for message \(header.id, privacy: .public)")
            throw .decryptionFailed
        }

        let signature: Data
        do {
            signature = try keys.signing.signature(for: aad + ciphertext)
        } catch {
            CryptoLog.engine.error("Signing failed for message \(header.id, privacy: .public)")
            throw .identityUnavailable
        }

        CryptoLog.engine.debug("Sealed message \(header.id, privacy: .public) counter \(header.counter, privacy: .public)")
        return Envelope(header: header, ciphertext: ciphertext, signature: signature, version: version)
    }

    public func open(_ envelope: Envelope, peer: PublicKeyBundle, myUserId: UserID) async throws(CryptoError) -> MessagePayload {
        try Self.validateLengths(peer)
        let keys = try await loadKeys()
        let aad = AssociatedData.canonical(for: envelope)

        // Own history (sync after reinstall) is verified against this device's key; everything else
        // against the peer's pinned key. A sender id matching neither simply fails verification.
        let verifyingKey: Curve25519.Signing.PublicKey
        if envelope.senderId == myUserId {
            verifyingKey = keys.signing.publicKey
        } else {
            verifyingKey = try Self.signingPublicKey(peer.signingKey)
        }
        guard verifyingKey.isValidSignature(envelope.signature, for: aad + envelope.ciphertext) else {
            CryptoLog.engine.warning("Invalid signature on message \(envelope.id, privacy: .public)")
            throw .invalidSignature
        }

        let context = DerivationContext(
            conversationId: envelope.conversationId,
            senderId: envelope.senderId,
            counter: envelope.counter,
            version: envelope.version
        )
        let messageKey = try Self.messageKey(mine: keys.agreement, theirIdentityKey: peer.identityKey, context: context)

        let plaintext: Data
        do {
            let box = try ChaChaPoly.SealedBox(combined: envelope.ciphertext)
            plaintext = try ChaChaPoly.open(box, using: messageKey, authenticating: aad)
        } catch {
            CryptoLog.engine.warning("Decryption failed for message \(envelope.id, privacy: .public)")
            throw .decryptionFailed
        }

        do {
            return try codec.decode(plaintext)
        } catch {
            CryptoLog.engine.warning("Malformed payload in message \(envelope.id, privacy: .public)")
            throw .malformedPayload
        }
    }

    // MARK: - Attachments & fingerprints (pure; safe to call from any isolation)

    public nonisolated func attachmentKey() -> Data {
        AttachmentCipher.randomKey()
    }

    public nonisolated func sealBlob(_ data: Data, key: Data) throws(CryptoError) -> Data {
        try AttachmentCipher.seal(data, key: key)
    }

    public nonisolated func openBlob(_ data: Data, key: Data) throws(CryptoError) -> Data {
        try AttachmentCipher.open(data, key: key)
    }

    public nonisolated func fingerprint(mine: PublicKeyBundle, theirs: PublicKeyBundle) -> SafetyFingerprint {
        SafetyFingerprintGenerator.generate(mine: mine, theirs: theirs)
    }

    // MARK: - Helpers

    private func loadKeys() async throws(CryptoError) -> IdentityPrivateKeys {
        do {
            return try await keyProvider.privateKeys()
        } catch {
            CryptoLog.engine.error("Identity keys unavailable")
            throw .identityUnavailable
        }
    }

    private static func validateLengths(_ bundle: PublicKeyBundle) throws(CryptoError) {
        guard bundle.identityKey.count == PublicKeyBundle.keyLength else {
            throw .keyLength(expected: PublicKeyBundle.keyLength, actual: bundle.identityKey.count)
        }
        guard bundle.signingKey.count == PublicKeyBundle.keyLength else {
            throw .keyLength(expected: PublicKeyBundle.keyLength, actual: bundle.signingKey.count)
        }
    }

    private static func signingPublicKey(_ raw: Data) throws(CryptoError) -> Curve25519.Signing.PublicKey {
        do {
            return try Curve25519.Signing.PublicKey(rawRepresentation: raw)
        } catch {
            throw .keyLength(expected: PublicKeyBundle.keyLength, actual: raw.count)
        }
    }

    /// Everything besides the two identity keys that the message key depends on. Taken from the
    /// header on seal and from the envelope itself on open, so the receiver derives from exactly the
    /// values the sender authenticated.
    private struct DerivationContext {
        let conversationId: ConversationID
        let senderId: UserID
        let counter: UInt64
        let version: Int
    }

    private static func messageKey(
        mine: Curve25519.KeyAgreement.PrivateKey,
        theirIdentityKey: Data,
        context: DerivationContext
    ) throws(CryptoError) -> SymmetricKey {
        let shared: SharedSecret
        do {
            let theirs = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirIdentityKey)
            shared = try mine.sharedSecretFromKeyAgreement(with: theirs)
        } catch {
            throw .keyLength(expected: PublicKeyBundle.keyLength, actual: theirIdentityKey.count)
        }
        let root = KeyDerivation.rootKey(shared: shared, conversationId: context.conversationId, version: context.version)
        return KeyDerivation.messageKey(
            root: root,
            counter: context.counter,
            senderId: context.senderId,
            version: context.version
        )
    }
}
