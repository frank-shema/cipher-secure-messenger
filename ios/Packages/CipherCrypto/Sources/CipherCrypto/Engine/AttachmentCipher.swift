import CipherCore
import CryptoKit
import Foundation

/// Attachment blob encryption (PROTOCOL.md §3): one random 256-bit key per attachment, ChaChaPoly in
/// combined form (`nonce ‖ ciphertext ‖ tag`). The key travels inside the message ciphertext, so the
/// relay stores an opaque blob and never learns its type, name or content. The SHA-256 of the
/// encrypted blob lets the recipient confirm the download is the blob the sender described before
/// spending time decrypting it.
public enum AttachmentCipher {
    public static let keyLength = 32

    /// A fresh key from the system CSPRNG. Never reused across attachments, because ChaChaPoly's random
    /// nonce makes reuse safe only probabilistically and a per-file key costs nothing.
    public static func randomKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    public static func seal(_ data: Data, key: Data) throws(CryptoError) -> Data {
        let symmetricKey = try symmetricKey(from: key)
        do {
            return try ChaChaPoly.seal(data, using: symmetricKey).combined
        } catch {
            CryptoLog.engine.error("Attachment seal failed (size: \(data.count, privacy: .public))")
            throw .decryptionFailed
        }
    }

    public static func open(_ data: Data, key: Data) throws(CryptoError) -> Data {
        let symmetricKey = try symmetricKey(from: key)
        do {
            let box = try ChaChaPoly.SealedBox(combined: data)
            return try ChaChaPoly.open(box, using: symmetricKey)
        } catch {
            CryptoLog.engine.error("Attachment open failed (size: \(data.count, privacy: .public))")
            throw .decryptionFailed
        }
    }

    /// Lowercase hex digest of the (encrypted) blob, the format the `attachment.sha256` field carries.
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func symmetricKey(from key: Data) throws(CryptoError) -> SymmetricKey {
        guard key.count == keyLength else {
            throw .keyLength(expected: keyLength, actual: key.count)
        }
        return SymmetricKey(data: key)
    }
}
