import os

/// Loggers for the shoulder-surf features. Only state transitions and counts are logged: orientation
/// samples are never written out, because a stream of "face down at 21:14" lines is itself a record
/// of when someone felt watched.
enum PrivacyLog {
    private static let subsystem = "com.cipher.app"

    static let flipToHide = Logger(subsystem: subsystem, category: "privacy.flipToHide")
    static let curtain = Logger(subsystem: subsystem, category: "privacy.curtain")
}
