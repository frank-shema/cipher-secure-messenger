import CipherCore
import Foundation

/// Deterministic sample data for previews and mock gateways. Ids are fixed so previews look the same
/// on every run and so the mock directory can pre-seed keys for the sample contacts.
enum Fixtures {
    static let aliceId = UserID(uuidString: "5f3a7c1e-8b2d-4e6f-9a0b-1c2d3e4f5a6b") ?? UserID()
    static let bobId = UserID(uuidString: "9d4e5f6a-7b8c-4d9e-8f1a-2b3c4d5e6f7a") ?? UserID()
    static let echoId = UserID(uuidString: "0c9f2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f") ?? UserID()

    static let alice = User(id: aliceId, username: "alice", displayName: "Alice")
    static let bob = User(id: bobId, username: "bob", displayName: "Bob")
    static let echo = User(id: echoId, username: "cipher-echo", displayName: "Echo")

    static let users: [User] = [alice, bob, echo]

    /// The relay's seeded development accounts share this password.
    static let password = "cipher-demo"

    static func session(for user: User, now: Date = Date()) -> Session {
        Session(
            user: user,
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            accessTokenExpiresAt: now.addingTimeInterval(900)
        )
    }

    /// Stable, obviously synthetic 32-byte keys: a repeating byte pattern seeded per user.
    static func keyBundle(for user: User, version: Int = 1) -> PublicKeyBundle {
        PublicKeyBundle(
            userId: user.id,
            identityKey: syntheticKey(seed: user.username, salt: 0x1D),
            signingKey: syntheticKey(seed: user.username, salt: 0x51),
            version: version,
            createdAt: Date(epochMillis: 1_758_708_000_000)
        )
    }

    static func syntheticKey(seed: String, salt: UInt8) -> Data {
        var state: UInt8 = salt
        var bytes = [UInt8](repeating: 0, count: PublicKeyBundle.keyLength)
        let seedBytes = Array(seed.utf8)
        for index in bytes.indices {
            state = state &+ seedBytes[index % max(seedBytes.count, 1)] &+ UInt8(truncatingIfNeeded: index * 7)
            bytes[index] = state
        }
        return Data(bytes)
    }
}
