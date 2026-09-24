import os

/// Loggers for app lock and the decoy inbox. Never log a PIN, a digest, or which mode a PIN opened:
/// the whole point of a duress PIN is that nothing on the device records that it was used.
enum LockLog {
    private static let subsystem = "com.cipher.app"

    static let lock = Logger(subsystem: subsystem, category: "lock")
    static let vault = Logger(subsystem: subsystem, category: "lock.vault")
    static let decoy = Logger(subsystem: subsystem, category: "lock.decoy")
}
