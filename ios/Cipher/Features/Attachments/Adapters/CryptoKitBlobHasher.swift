import CipherCore
import CryptoKit
import Foundation

/// `BlobHashing` over CryptoKit. SHA-256 of the *sealed* blob is what travels in the payload, so the
/// recipient can reject a swapped or truncated download before spending a key on it.
struct CryptoKitBlobHasher: BlobHashing {
    func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
