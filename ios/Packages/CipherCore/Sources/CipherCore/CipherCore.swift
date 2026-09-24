import Foundation
import os

/// Namespace for module-wide constants.
public enum CipherCore {
    /// Wire protocol version (docs/PROTOCOL.md). Every envelope, encrypted payload and realtime frame
    /// carries it so both ends can refuse shapes they do not understand instead of misreading them.
    public static let protocolVersion = 1
}

/// Module loggers with stable categories so Console filters keep working across releases.
/// Never log plaintext, key material, tokens or ciphertext: identifiers and counts only.
enum CoreLog {
    static let useCases = Logger(subsystem: "com.cipher.core", category: "usecases")
}

/// Resolves user-facing strings through this package's String Catalog so every sentence a person can
/// read is translatable, while the call site keeps a readable English default.
enum CoreStrings {
    static func localized(_ key: StaticString, default value: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: value, bundle: .module)
    }
}
