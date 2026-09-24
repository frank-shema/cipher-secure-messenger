import os

/// Loggers for the verification feature. Fingerprints, safety numbers and QR payloads are public
/// material by design, but they still identify a conversation pair, so only user ids, versions and
/// outcomes are logged: never the emoji, the digits or a scanned payload.
enum VerifyLog {
    private static let subsystem = "com.cipher.app"

    static let verify = Logger(subsystem: subsystem, category: "verify")
    static let scanner = Logger(subsystem: subsystem, category: "qr-scanner")
}
