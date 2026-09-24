import Foundation

/// The disappearing-message presets offered in the conversation header. Raw values are seconds so
/// the enum converts losslessly to `MessageFlags.disappearAfter` and `Conversation.disappearingTimer`,
/// which is what actually travels inside the ciphertext.
public enum DisappearingTimer: TimeInterval, Hashable, Codable, Sendable, CaseIterable, Identifiable {
    case off = 0
    case thirtySeconds = 30
    case fiveMinutes = 300
    case oneHour = 3_600
    case oneDay = 86_400

    public var id: TimeInterval {
        rawValue
    }

    /// Nearest preset to an arbitrary interval, so a timer set by another client (or an older build
    /// with different presets) still lands on a menu row instead of showing nothing selected.
    public init(seconds: TimeInterval?) {
        guard let seconds, seconds > 0 else {
            self = .off
            return
        }
        let closest = Self.allCases
            .filter { $0 != .off }
            .min { abs($0.rawValue - seconds) < abs($1.rawValue - seconds) }
        self = closest ?? .off
    }

    /// Seconds after read, or nil when disabled: the value stored in the flags.
    public var seconds: TimeInterval? {
        self == .off ? nil : rawValue
    }

    public var isEnabled: Bool {
        self != .off
    }

    /// Catalog key for the menu label, e.g. `disappearing.timer.fiveMinutes`.
    public var titleKey: String {
        "disappearing.timer.\(caseName)"
    }

    /// When a message read at `readAt` must be deleted, or nil when the timer is off.
    public func expiryDate(readAt: Date) -> Date? {
        seconds.map { readAt.addingTimeInterval($0) }
    }

    /// An unread message never expires: the timer runs from *read*, so a recipient who has been
    /// offline for a week still gets to see the message once.
    public func isExpired(readAt: Date?, now: Date) -> Bool {
        guard let readAt, let expiry = expiryDate(readAt: readAt) else { return false }
        return now >= expiry
    }

    /// Seconds left before deletion, clamped at zero; nil when off or unread.
    public func remaining(readAt: Date?, now: Date) -> TimeInterval? {
        guard let readAt, let expiry = expiryDate(readAt: readAt) else { return nil }
        return max(0, expiry.timeIntervalSince(now))
    }

    /// The effective deletion instant for a message: the per-message flag wins over the conversation
    /// default because the sender chose it explicitly for that message.
    public static func expiryDate(for flags: MessageFlags, conversationDefault: TimeInterval?, readAt: Date?) -> Date? {
        guard let readAt else { return nil }
        let timer = DisappearingTimer(seconds: flags.disappearAfter ?? conversationDefault)
        return timer.expiryDate(readAt: readAt)
    }

    private var caseName: String {
        switch self {
        case .off: "off"
        case .thirtySeconds: "thirtySeconds"
        case .fiveMinutes: "fiveMinutes"
        case .oneHour: "oneHour"
        case .oneDay: "oneDay"
        }
    }
}
