import os

/// App-target loggers with stable categories so Console filters keep working across releases.
/// Never log tokens, key material, plaintext or ciphertext: identifiers, counts and phases only.
enum AppLog {
    private static let subsystem = "com.cipher.app"

    static let session = Logger(subsystem: subsystem, category: "session")
    static let container = Logger(subsystem: subsystem, category: "container")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let identity = Logger(subsystem: subsystem, category: "identity")
    static let onboarding = Logger(subsystem: subsystem, category: "onboarding")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let router = Logger(subsystem: subsystem, category: "router")
}
