import Foundation
import os

/// Namespace for module-wide constants.
public enum CipherCrypto {
    public static let moduleName = "CipherCrypto"

    /// Default Keychain service under which the app's own identity keys live. The DEBUG demo
    /// companion uses a different service so its keys can never be mistaken for the user's.
    public static let defaultKeychainService = "com.cipher.identity"
}

/// Module loggers with stable categories so Console filters keep working across releases.
/// Never log plaintext, key material, tokens or ciphertext: identifiers, lengths and counts only.
enum CryptoLog {
    static let engine = Logger(subsystem: "com.cipher.crypto", category: "engine")
    static let keyStore = Logger(subsystem: "com.cipher.crypto", category: "keystore")
    static let fingerprint = Logger(subsystem: "com.cipher.crypto", category: "fingerprint")
}

/// Resolves user-facing strings through this package's String Catalog so every sentence a person can
/// read is translatable, while the call site keeps a readable English default.
enum CryptoStrings {
    static func localized(_ key: StaticString, default value: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: value, bundle: .module)
    }
}
