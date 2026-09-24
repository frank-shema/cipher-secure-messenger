import CipherCore
import Foundation

/// Feeds `CountdownRing` for a disappearing message: progress, remaining time and how often to
/// re-render. Pure values so a row can evaluate it on every timeline tick without allocation, and
/// so previews can freeze `now`.
struct ExpiryCountdown: Hashable, Sendable {
    let sentAt: Date
    let expiresAt: Date

    /// Nil when the message does not expire.
    init?(message: Message) {
        guard let expiresAt = message.expiresAt else { return nil }
        self.init(sentAt: message.sentAt, expiresAt: expiresAt)
    }

    init(sentAt: Date, expiresAt: Date) {
        self.sentAt = sentAt
        self.expiresAt = expiresAt
    }

    /// The full window, never below one second so progress stays finite for a malformed pair.
    var total: TimeInterval {
        max(expiresAt.timeIntervalSince(sentAt), 1)
    }

    /// Seconds left, clamped at zero.
    func remaining(at now: Date) -> TimeInterval {
        max(0, expiresAt.timeIntervalSince(now))
    }

    /// Fraction of the window still left, `0...1`: the ring empties as time runs out. Clamped
    /// here rather than through `CountdownRing.clamp`, which is main-actor-isolated as a View
    /// static, so this value type stays usable from any isolation.
    func progress(at now: Date) -> Double {
        let fraction = remaining(at: now) / total
        return fraction.isNaN ? 0 : min(max(fraction, 0), 1)
    }

    func isExpired(at now: Date) -> Bool {
        now >= expiresAt
    }

    /// The last ten seconds get the warning tint so the bubble visibly runs out.
    func isUrgent(at now: Date) -> Bool {
        remaining(at: now) <= 10 && !isExpired(at: now)
    }

    /// Compact label such as "45s" or "2h", using the same thresholds as `CountdownRing.label` so
    /// the ring and any text next to it never disagree.
    func label(at now: Date) -> String {
        Self.label(forRemaining: remaining(at: now))
    }

    static func label(forRemaining seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        switch whole {
        case ..<60: return "\(whole)s"
        case ..<3_600: return "\(whole / 60)m"
        case ..<86_400: return "\(whole / 3_600)h"
        default: return "\(whole / 86_400)d"
        }
    }

    /// Ticking once a second only matters when the label shows seconds; longer windows re-render
    /// once a minute so a transcript full of one-day timers does not burn the battery.
    func refreshInterval(at now: Date) -> TimeInterval {
        remaining(at: now) <= 60 ? 1 : 60
    }

    /// VoiceOver text for the ring.
    func accessibilityLabel(at now: Date) -> String {
        if isExpired(at: now) {
            return String(localized: "expiry.countdown.a11y.expired", defaultValue: "Expired")
        }
        return String(localized: "expiry.countdown.a11y.remaining", defaultValue: "Disappears in \(label(at: now))")
    }
}
