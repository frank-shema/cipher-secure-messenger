import os

/// Loggers for disappearing messages and Time Capsules. Only message and conversation identifiers,
/// counts, cadences and instants are ever interpolated: never a body, a timer's meaning for a
/// person, or anything derived from plaintext.
enum EphemeralLog {
    private static let subsystem = "com.cipher.app"

    static let expiry = Logger(subsystem: subsystem, category: "ephemeral.expiry")
    static let capsule = Logger(subsystem: subsystem, category: "ephemeral.capsule")
    static let timer = Logger(subsystem: subsystem, category: "ephemeral.timer")
}
