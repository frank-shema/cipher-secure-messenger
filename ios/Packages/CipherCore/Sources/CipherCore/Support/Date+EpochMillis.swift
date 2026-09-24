import Foundation

public extension Date {
    /// Converts a wire timestamp (Unix epoch milliseconds, PROTOCOL.md conventions) to a `Date`.
    init(epochMillis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1_000)
    }

    /// Unix epoch milliseconds, rounded so a value round-trips byte-for-byte through `Date`.
    /// The envelope timestamp is part of the AEAD associated data, so any drift here would make
    /// a perfectly valid message fail authentication.
    var epochMillis: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }
}
