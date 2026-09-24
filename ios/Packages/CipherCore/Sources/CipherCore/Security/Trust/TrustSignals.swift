import Foundation

/// The observable facts a trust score is computed from. Reduced to booleans and a day count so the
/// evaluator stays a pure function that the Trust Meter, its previews and the settings screen can
/// all feed without touching a repository.
public struct TrustSignals: Hashable, Sendable {
    /// How long a `keyChanged` event counts as recent. A fortnight is long enough that the person has
    /// almost certainly opened the conversation since, and short enough that an impersonation attempt
    /// still in progress keeps its warning.
    public static let recentKeyChangeWindow: TimeInterval = 14 * 24 * 60 * 60

    /// The safety fingerprint was compared out of band.
    public var verified: Bool
    /// Age of the pinned key bundle. Older keys have survived more conversations without a
    /// `key.changed` event, which is weak but real evidence that nobody has swapped them.
    public var keyAgeDays: Int
    /// The conversation has a default disappearing timer.
    public var disappearingEnabled: Bool
    /// Attachments are stripped of EXIF/location metadata before they are encrypted.
    public var metadataStrippingEnabled: Bool
    /// The pinned keys changed inside `recentKeyChangeWindow` and nobody re-verified.
    public var keyChangedRecently: Bool

    public init(
        verified: Bool,
        keyAgeDays: Int,
        disappearingEnabled: Bool,
        metadataStrippingEnabled: Bool,
        keyChangedRecently: Bool
    ) {
        self.verified = verified
        self.keyAgeDays = max(0, keyAgeDays)
        self.disappearingEnabled = disappearingEnabled
        self.metadataStrippingEnabled = metadataStrippingEnabled
        self.keyChangedRecently = keyChangedRecently
    }

    /// Derives the signals from the domain entities. `metadataStrippingEnabled` is an app-level
    /// preference rather than a property of the contact, so the caller supplies it.
    public init(contact: Contact, disappearingTimer: TimeInterval?, metadataStrippingEnabled: Bool, now: Date) {
        let keyAge = contact.keys.map { now.timeIntervalSince($0.createdAt) } ?? 0
        let changedRecently: Bool
        if case .keyChanged(_, let changedAt) = contact.trust {
            changedRecently = now.timeIntervalSince(changedAt) < Self.recentKeyChangeWindow
        } else {
            changedRecently = false
        }
        self.init(
            verified: contact.trust.isVerified,
            keyAgeDays: Int((max(0, keyAge) / 86_400).rounded(.down)),
            disappearingEnabled: (disappearingTimer ?? 0) > 0,
            metadataStrippingEnabled: metadataStrippingEnabled,
            keyChangedRecently: changedRecently
        )
    }

    /// A brand-new, unverified contact with every protection off: the floor of the meter.
    public static let baseline = TrustSignals(
        verified: false,
        keyAgeDays: 0,
        disappearingEnabled: false,
        metadataStrippingEnabled: false,
        keyChangedRecently: false
    )
}
