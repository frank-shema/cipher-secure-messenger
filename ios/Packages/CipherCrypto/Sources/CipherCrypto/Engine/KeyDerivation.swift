import CipherCore
import CryptoKit
import Foundation

/// The two HKDF steps of PROTOCOL.md §4, kept byte-exact and in one place so the engine and any
/// future interoperability test derive keys from the same labels.
///
/// ```
/// root   = HKDF-SHA256(ikm = X25519(myIdentityPriv, theirIdentityPub),
///                      salt = utf8(conversationId), info = utf8("cipher/v1/root"), 32)
/// msgKey = HKDF-SHA256(ikm = root, salt = bigEndian64(counter),
///                      info = utf8("cipher/v1/msg|" + senderId), 32)
/// ```
///
/// Binding the sender id into the info string makes the two directions of a conversation use
/// disjoint keys even though both sides hold the same root, so a reflected envelope can never be
/// opened as if it came from the other party.
enum KeyDerivation {
    static let keyByteCount = 32

    static func rootInfo(version: Int) -> Data {
        Data("cipher/v\(version)/root".utf8)
    }

    static func messageInfo(senderId: UserID, version: Int) -> Data {
        Data("cipher/v\(version)/msg|\(senderId)".utf8)
    }

    /// 8-byte big-endian counter; the wire's integer must serialise identically on every platform.
    static func counterSalt(_ counter: UInt64) -> Data {
        withUnsafeBytes(of: counter.bigEndian) { Data($0) }
    }

    static func rootKey(shared: SharedSecret, conversationId: ConversationID, version: Int) -> SymmetricKey {
        shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(conversationId.description.utf8),
            sharedInfo: rootInfo(version: version),
            outputByteCount: keyByteCount
        )
    }

    static func messageKey(root: SymmetricKey, counter: UInt64, senderId: UserID, version: Int) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: root,
            salt: counterSalt(counter),
            info: messageInfo(senderId: senderId, version: version),
            outputByteCount: keyByteCount
        )
    }
}
