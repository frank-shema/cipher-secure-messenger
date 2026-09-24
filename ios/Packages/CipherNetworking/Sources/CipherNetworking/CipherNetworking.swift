import Foundation
import os

/// Namespace for module-wide constants.
public enum CipherNetworking {
    public static let moduleName = "CipherNetworking"

    /// REST base path (PROTOCOL.md §1). Kept separate from the host so a Settings override only has to
    /// supply `scheme://host:port`.
    public static let restBasePath = "api/v1"
}

/// Module loggers with stable categories so Console filters keep working across releases.
/// Never log tokens, key material, ciphertext or plaintext: identifiers, status codes and counts only.
enum NetLog {
    static let api = Logger(subsystem: "com.cipher.networking", category: "api")
    static let realtime = Logger(subsystem: "com.cipher.networking", category: "realtime")
    static let attachments = Logger(subsystem: "com.cipher.networking", category: "attachments")
}

/// Resolves user-facing strings through this package's String Catalog so every sentence a person can
/// read is translatable, while the call site keeps a readable English default.
enum NetStrings {
    static func localized(_ key: StaticString, default value: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: value, bundle: .module)
    }
}
