import Foundation

/// How much the local user has vouched for a contact's pinned keys.
public enum TrustState: Hashable, Codable, Sendable {
    /// Keys were pinned from the directory but never compared out of band.
    case unverified
    /// The safety fingerprint was compared (emoji or QR) at this time.
    case verified(at: Date)
    /// The directory or a `key.changed` event presented different key material than the pinned one.
    /// Shown as a warning until the person re-verifies, because this is exactly what an
    /// impersonating relay would look like.
    case keyChanged(previousVersion: Int, at: Date)

    public var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }

    public var needsAttention: Bool {
        if case .keyChanged = self { return true }
        return false
    }
}
