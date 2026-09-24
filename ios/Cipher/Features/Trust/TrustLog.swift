import os

/// Logger for the Trust Ring feature. Trust verdicts sit next to contact identity, so entries carry
/// levels, percentages and reason kinds only: never a name, a key or a fingerprint.
enum TrustLog {
    static let trust = Logger(subsystem: "com.cipher.app", category: "trust")
}
