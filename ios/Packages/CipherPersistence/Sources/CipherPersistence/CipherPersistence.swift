import Foundation
import os

/// Namespace for module-wide constants.
public enum CipherPersistence {
    public static let moduleName = "CipherPersistence"

    /// Folder under Application Support that holds every account's store. One folder per account keeps
    /// two identities on the same device (the person and the DEBUG demo companion) from ever sharing
    /// a message table or a counter.
    public static let rootDirectoryName = "Cipher"

    /// File name of the SwiftData store inside an account directory.
    public static let storeFileName = "cipher.store"
}

/// Module loggers with stable categories so Console filters keep working across releases.
/// Never log plaintext, key material, tokens, ciphertext or envelope bytes: identifiers and counts only.
enum PersistenceLog {
    static let store = Logger(subsystem: "com.cipher.persistence", category: "store")
    static let observation = Logger(subsystem: "com.cipher.persistence", category: "observation")
    static let configuration = Logger(subsystem: "com.cipher.persistence", category: "configuration")
}

/// Resolves user-facing strings through this package's String Catalog so every sentence a person can
/// read is translatable, while the call site keeps a readable English default.
enum PersistenceStrings {
    static func localized(_ key: StaticString, default value: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: value, bundle: .module)
    }
}
