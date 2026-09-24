import CipherCore
import CryptoKit
import Foundation
import os

/// The two PINs the lock knows about. Each has its own Keychain service, separate from the session
/// tokens, so an audit of one item class never has to touch the others.
enum PINKind: String, CaseIterable, Sendable {
    case real
    case decoy

    var keychainService: String {
        switch self {
        case .real: "com.cipher.applock.pin"
        case .decoy: "com.cipher.applock.duress"
        }
    }
}

enum PINVaultError: Error, LocalizedError, Hashable, Sendable {
    case storageFailed(String)
    case corruptRecord

    var errorDescription: String? {
        switch self {
        case .storageFailed:
            String(localized: "error.pinVault.storage", defaultValue: "The PIN could not be saved to the secure store.")
        case .corruptRecord:
            String(localized: "error.pinVault.corrupt", defaultValue: "The stored PIN record is unreadable. Set the PIN again.")
        }
    }
}

/// Stores and checks the app PINs. Refines Core's `PINVerifier` so the lock manager can be handed any
/// verifier without knowing whether a Keychain is behind it.
protocol PINVault: PINVerifier {
    func hasPIN(_ kind: PINKind) -> Bool
    func store(_ pin: String, kind: PINKind) async throws(PINVaultError)
    func remove(_ kind: PINKind) throws(PINVaultError)
    /// True only when `pin` matches the stored PIN of that kind. Used by settings, never by the lock screen.
    func matches(_ pin: String, kind: PINKind) async -> Bool
}

/// What is actually written to the Keychain: a salt, an iteration count and the resulting digest.
/// Storing the count lets the cost be raised later without invalidating existing PINs.
struct PINRecord: Codable, Hashable, Sendable {
    var version: Int
    var salt: Data
    var rounds: Int
    var digest: Data
}

/// Salted, iterated SHA-256 over the PIN. A 4–8 digit space is tiny, so a single hash would fall to an
/// offline guess in milliseconds; iterating raises the cost per guess by four orders of magnitude while
/// staying imperceptible on a single unlock. Comparison is constant time so timing never leaks how many
/// digits were right.
enum PINDigest {
    static let currentVersion = 1
    static let rounds = 32_768
    static let saltLength = 16

    static func makeSalt() -> Data {
        SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    }

    static func compute(pin: String, salt: Data, rounds: Int) -> Data {
        var digest = Data(SHA256.hash(data: salt + Data(pin.utf8)))
        for _ in 1..<max(rounds, 1) {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }

    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

/// Keychain-backed vault. A missing decoy is checked against a fixed placeholder record so the work done,
/// and therefore the time taken, is identical whether or not a duress PIN exists.
struct KeychainPINVault: PINVault {
    private static let account = "pin.v1"
    private static let placeholder = PINRecord(
        version: PINDigest.currentVersion,
        salt: Data(repeating: 0x5A, count: PINDigest.saltLength),
        rounds: PINDigest.rounds,
        digest: Data(repeating: 0, count: SHA256.byteCount)
    )

    private let stores: [PINKind: KeychainStore]

    init() {
        var stores: [PINKind: KeychainStore] = [:]
        for kind in PINKind.allCases {
            stores[kind] = KeychainStore(service: kind.keychainService)
        }
        self.stores = stores
    }

    func hasPIN(_ kind: PINKind) -> Bool {
        load(kind) != nil
    }

    func store(_ pin: String, kind: PINKind) async throws(PINVaultError) {
        let salt = PINDigest.makeSalt()
        let digest = await Task.detached(priority: .userInitiated) {
            PINDigest.compute(pin: pin, salt: salt, rounds: PINDigest.rounds)
        }.value
        let record = PINRecord(version: PINDigest.currentVersion, salt: salt, rounds: PINDigest.rounds, digest: digest)
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(record)
        } catch {
            throw PINVaultError.corruptRecord
        }
        do {
            try stores[kind]?.write(encoded, account: Self.account)
        } catch {
            LockLog.vault.error("store failed kind=\(kind.rawValue, privacy: .public) \(String(describing: error), privacy: .public)")
            throw PINVaultError.storageFailed(String(describing: type(of: error)))
        }
        LockLog.vault.info("stored kind=\(kind.rawValue, privacy: .public)")
    }

    func remove(_ kind: PINKind) throws(PINVaultError) {
        do {
            try stores[kind]?.delete(account: Self.account)
        } catch {
            throw PINVaultError.storageFailed(String(describing: type(of: error)))
        }
        LockLog.vault.info("removed kind=\(kind.rawValue, privacy: .public)")
    }

    func matches(_ pin: String, kind: PINKind) async -> Bool {
        let stored = load(kind)
        let record = stored ?? Self.placeholder
        let candidate = await Task.detached(priority: .userInitiated) {
            PINDigest.compute(pin: pin, salt: record.salt, rounds: record.rounds)
        }.value
        let equal = PINDigest.constantTimeEquals(candidate, record.digest)
        return stored != nil && equal
    }

    /// Checks both kinds every time so a wrong PIN, a real PIN and a decoy PIN all take the same path.
    func verify(_ pin: String) async -> AppLockMode? {
        let real = await matches(pin, kind: .real)
        let decoy = await matches(pin, kind: .decoy)
        if real { return .real }
        if decoy { return .decoy }
        return nil
    }

    private func load(_ kind: PINKind) -> PINRecord? {
        guard let store = stores[kind] else { return nil }
        let data: Data?
        do {
            data = try store.read(account: Self.account)
        } catch {
            LockLog.vault.error("read failed kind=\(kind.rawValue, privacy: .public)")
            return nil
        }
        guard let data else { return nil }
        return try? JSONDecoder().decode(PINRecord.self, from: data)
    }
}

/// Holds PINs in memory as plain strings. Previews only: nothing here is hashed.
final class InMemoryPINVault: PINVault, Sendable {
    private let pins = OSAllocatedUnfairLock<[PINKind: String]>(initialState: [:])

    init(real: String? = nil, decoy: String? = nil) {
        pins.withLock { state in
            state[.real] = real
            state[.decoy] = decoy
        }
    }

    func hasPIN(_ kind: PINKind) -> Bool {
        pins.withLock { $0[kind] != nil }
    }

    func store(_ pin: String, kind: PINKind) async throws(PINVaultError) {
        pins.withLock { $0[kind] = pin }
    }

    func remove(_ kind: PINKind) throws(PINVaultError) {
        pins.withLock { $0[kind] = nil }
    }

    func matches(_ pin: String, kind: PINKind) async -> Bool {
        guard let stored = pins.withLock({ $0[kind] }) else { return false }
        return PINRules.constantTimeEquals(pin, stored)
    }

    func verify(_ pin: String) async -> AppLockMode? {
        if await matches(pin, kind: .real) { return .real }
        if await matches(pin, kind: .decoy) { return .decoy }
        return nil
    }
}
