import CipherCore
import Foundation

/// Where a `PersistenceStore` keeps its data. Stores are scoped to one account so switching accounts on
/// a device never mixes histories, counters or replay records.
public struct PersistenceConfiguration: Hashable, Sendable {
    public enum Storage: Hashable, Sendable {
        /// Nothing touches disk. Used by previews, tests and the DEBUG demo companion.
        case inMemory
        /// A SwiftData store file inside a directory this module created with full file protection.
        case onDisk(url: URL)
    }

    public var storage: Storage
    /// The account this store belongs to; nil for anonymous in-memory stores.
    public var accountId: UserID?

    public init(storage: Storage, accountId: UserID? = nil) {
        self.storage = storage
        self.accountId = accountId
    }

    /// An anonymous in-memory configuration.
    public static let inMemory = PersistenceConfiguration(storage: .inMemory, accountId: nil)

    /// An in-memory configuration tagged with an account, for a demo identity that must stay separate.
    public static func inMemory(accountId: UserID) -> PersistenceConfiguration {
        PersistenceConfiguration(storage: .inMemory, accountId: accountId)
    }

    public var isInMemory: Bool {
        storage == .inMemory
    }

    /// The on-disk configuration for `accountId`, creating `Application Support/Cipher/<accountId>/` with
    /// `NSFileProtectionComplete` and excluded from backups. Complete protection means the store is
    /// unreadable while the device is locked, which matches the Keychain policy used for the identity
    /// keys: ciphertext without keys is useless, but decrypted history at rest deserves the same bar.
    public static func onDisk(accountId: UserID, fileManager: FileManager = .default) throws(PersistenceError) -> PersistenceConfiguration {
        let directory = try AccountDirectory.prepare(for: accountId, fileManager: fileManager)
        let url = directory.appending(path: CipherPersistence.storeFileName, directoryHint: .notDirectory)
        return PersistenceConfiguration(storage: .onDisk(url: url), accountId: accountId)
    }

    /// Deletes the account directory and everything in it (store, journal, external blobs). Called on
    /// sign-out so no decrypted history outlives the session. Safe to call when nothing exists.
    public static func removeOnDiskStore(accountId: UserID, fileManager: FileManager = .default) throws(PersistenceError) {
        try AccountDirectory.remove(for: accountId, fileManager: fileManager)
    }
}

/// Filesystem layout for per-account stores.
enum AccountDirectory {
    static func url(for accountId: UserID, fileManager: FileManager) throws(PersistenceError) -> URL {
        let support: URL
        do {
            support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw .storageUnavailable(PersistenceError.typeName(of: error))
        }
        return support
            .appending(path: CipherPersistence.rootDirectoryName, directoryHint: .isDirectory)
            .appending(path: accountId.description, directoryHint: .isDirectory)
    }

    static func prepare(for accountId: UserID, fileManager: FileManager) throws(PersistenceError) -> URL {
        let directory = try url(for: accountId, fileManager: fileManager)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protectionAttributes)
            try applyProtection(to: directory, fileManager: fileManager)
            try excludeFromBackup(directory)
        } catch {
            let reason = PersistenceError.typeName(of: error)
            PersistenceLog.configuration.error(
                "account directory unavailable for \(accountId.description, privacy: .public): \(reason, privacy: .public)"
            )
            throw .storageUnavailable(PersistenceError.typeName(of: error))
        }
        return directory
    }

    static func remove(for accountId: UserID, fileManager: FileManager) throws(PersistenceError) {
        let directory = try url(for: accountId, fileManager: fileManager)
        guard fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        do {
            try fileManager.removeItem(at: directory)
            PersistenceLog.configuration.notice("removed store for \(accountId.description, privacy: .public)")
        } catch {
            throw .storageUnavailable(PersistenceError.typeName(of: error))
        }
    }

    /// `createDirectory` only applies attributes to a directory it creates, so an existing directory
    /// (from an earlier launch that predates the policy) is re-protected explicitly.
    private static func applyProtection(to directory: URL, fileManager: FileManager) throws {
        guard !protectionAttributes.isEmpty else { return }
        try fileManager.setAttributes(protectionAttributes, ofItemAtPath: directory.path(percentEncoded: false))
    }

    /// File protection classes exist only on Apple's mobile platforms; macOS relies on FileVault.
    private static var protectionAttributes: [FileAttributeKey: Any] {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        [.protectionKey: FileProtectionType.complete]
        #else
        [:]
        #endif
    }

    /// Decrypted history is rebuilt from the relay's ciphertext on a fresh install, so a backup copy
    /// would only widen the set of places plaintext can be recovered from.
    private static func excludeFromBackup(_ directory: URL) throws {
        var target = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
    }
}
