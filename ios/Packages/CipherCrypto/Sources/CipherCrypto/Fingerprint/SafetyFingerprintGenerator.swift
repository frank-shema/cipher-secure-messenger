import CipherCore
import CryptoKit
import Foundation

/// Safety fingerprint (PROTOCOL.md §4): `SHA-256(sorted([ikA ‖ skA, ikB ‖ skB]) joined)`. Sorting the
/// two byte strings before hashing is what makes the value symmetric, so Alice and Bob each compute
/// it from their own perspective and still see the same eight emoji. Both bundles contribute both
/// keys, so a swapped signing key alone changes the fingerprint.
public enum SafetyFingerprintGenerator {
    /// Number of digest bytes shown as emoji.
    public static let emojiCount = 8

    public static func generate(mine: PublicKeyBundle, theirs: PublicKeyBundle) -> SafetyFingerprint {
        let digest = digest(mine: mine, theirs: theirs)
        let emoji = digest.prefix(emojiCount).map { EmojiTable.emoji(for: $0) }
        CryptoLog.fingerprint.debug("Fingerprint computed for \(theirs.userId, privacy: .public)")
        return SafetyFingerprint(emoji: emoji, hex: groupedHex(digest))
    }

    /// The full 32-byte digest, exposed so the UI can offer a longer code for out-of-band comparison.
    public static func digest(mine: PublicKeyBundle, theirs: PublicKeyBundle) -> Data {
        let entries = [mine.identityKey + mine.signingKey, theirs.identityKey + theirs.signingKey]
        let joined = entries.sorted(by: lexicographicallyPrecedes).reduce(Data(), +)
        return Data(SHA256.hash(data: joined))
    }

    /// Uppercase hex in 4-character groups (`1A2B 3C4D …`), the shape people can read aloud in pairs.
    static func groupedHex(_ digest: Data) -> String {
        let hex = digest.map { String(format: "%02X", $0) }.joined()
        var groups: [String] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 4, limitedBy: hex.endIndex) ?? hex.endIndex
            groups.append(String(hex[index..<next]))
            index = next
        }
        return groups.joined(separator: " ")
    }

    private static func lexicographicallyPrecedes(_ lhs: Data, _ rhs: Data) -> Bool {
        lhs.lexicographicallyPrecedes(rhs)
    }
}
