import Foundation

/// Whether a Time Capsule message may be opened yet. Enforced purely on the recipient's device: the
/// relay never sees `unlockAt`, so this is a courtesy the app extends to the sender, not a guarantee.
public enum TimeCapsuleState: Hashable, Sendable {
    /// Still locked; `remaining` seconds until it opens, never negative.
    case sealed(remaining: TimeInterval)
    case unlocked

    public init(unlockAt: Date?, now: Date) {
        guard let unlockAt, unlockAt > now else {
            self = .unlocked
            return
        }
        self = .sealed(remaining: unlockAt.timeIntervalSince(now))
    }

    /// Convenience for the row renderer: reads the flag straight off the message.
    public init(flags: MessageFlags, now: Date) {
        self.init(unlockAt: flags.unlockAt, now: now)
    }

    public var isSealed: Bool {
        if case .sealed = self { return true }
        return false
    }

    public var remaining: TimeInterval? {
        if case .sealed(let remaining) = self { return remaining }
        return nil
    }

    /// 0…1 share of the wait already elapsed, for a progress ring. A capsule with no send time or an
    /// unlock in the past reads as complete.
    public static func progress(sentAt: Date, unlockAt: Date, now: Date) -> Double {
        let total = unlockAt.timeIntervalSince(sentAt)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(sentAt)
        return min(max(elapsed / total, 0), 1)
    }

    /// How often a countdown label should re-render: every second in the last minute, every minute
    /// in the last hour, otherwise hourly. Ticking faster would only burn battery on a sealed row.
    public var suggestedRefreshInterval: TimeInterval? {
        guard case .sealed(let remaining) = self else { return nil }
        if remaining <= 60 { return 1 }
        if remaining <= 3_600 { return 60 }
        return 3_600
    }
}
