import CipherCore
import Foundation

/// The quick choices in the Time Capsule composer. The 30-second preset exists so a demo can show
/// a seal cracking open without waiting; the others are the real use.
enum TimeCapsulePreset: TimeInterval, Hashable, Sendable, CaseIterable, Identifiable {
    case demoThirtySeconds = 30
    case oneHour = 3_600
    case oneDay = 86_400

    var id: TimeInterval { rawValue }

    var interval: TimeInterval { rawValue }

    /// Only the demo preset is allowed under the one-minute floor a custom date must respect.
    var isDemo: Bool { self == .demoThirtySeconds }

    var title: String {
        switch self {
        case .demoThirtySeconds:
            String(localized: "capsule.preset.thirtySeconds", defaultValue: "30 s")
        case .oneHour:
            String(localized: "capsule.preset.oneHour", defaultValue: "1 hour")
        case .oneDay:
            String(localized: "capsule.preset.oneDay", defaultValue: "1 day")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .demoThirtySeconds:
            String(localized: "capsule.preset.a11y.thirtySeconds", defaultValue: "Open in 30 seconds, for demos")
        case .oneHour:
            String(localized: "capsule.preset.a11y.oneHour", defaultValue: "Open in one hour")
        case .oneDay:
            String(localized: "capsule.preset.a11y.oneDay", defaultValue: "Open in one day")
        }
    }
}

/// What the composer has picked: a relative preset or an absolute instant.
enum TimeCapsuleChoice: Hashable, Sendable {
    case preset(TimeCapsulePreset)
    case custom(Date)

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

/// Resolves a choice into the `unlockAt` that travels inside the ciphertext. Presets resolve at
/// seal time, not at pick time, so a sheet left open for a minute still produces "30 s from now".
struct TimeCapsuleSchedule: Sendable {
    /// A custom instant must be at least this far ahead; nearer than that the seal would open
    /// before the message is even acknowledged.
    static let minimumLead: TimeInterval = 60

    let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    /// The earliest instant the custom picker accepts.
    var earliestCustom: Date {
        now().addingTimeInterval(Self.minimumLead)
    }

    /// The instant a choice would open if sealed right now.
    func preview(_ choice: TimeCapsuleChoice) -> Date {
        switch choice {
        case .preset(let preset): now().addingTimeInterval(preset.interval)
        case .custom(let date): date
        }
    }

    /// Validates and resolves the choice at seal time.
    func resolve(_ choice: TimeCapsuleChoice) throws(EphemeralError) -> Date {
        switch choice {
        case .preset(let preset):
            return now().addingTimeInterval(preset.interval)
        case .custom(let date):
            let floor = earliestCustom
            guard date >= floor else { throw .unlockTooSoon(minimum: floor) }
            return date
        }
    }

    /// Progress of a sealed capsule for a ring, delegating to Core so rows and previews agree.
    static func progress(sentAt: Date, unlockAt: Date, now: Date) -> Double {
        TimeCapsuleState.progress(sentAt: sentAt, unlockAt: unlockAt, now: now)
    }
}
