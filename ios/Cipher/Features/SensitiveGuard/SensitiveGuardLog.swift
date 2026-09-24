import os

/// Logger for the sensitive-content guard. The guard reads unsent drafts, so entries carry finding
/// kinds, counts and timing only: never a character of the draft.
enum SensitiveGuardLog {
    static let guardian = Logger(subsystem: "com.cipher.app", category: "sensitiveGuard")
}
