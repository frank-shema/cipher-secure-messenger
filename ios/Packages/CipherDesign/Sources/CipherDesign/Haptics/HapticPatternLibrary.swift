import Foundation

/// A single haptic event in a pattern, expressed like an AHAP entry.
struct HapticEvent: Sendable {
    enum Kind: Sendable { case transient, continuous(duration: TimeInterval) }
    let kind: Kind
    /// Seconds from pattern start.
    let time: TimeInterval
    /// `0...1` strength.
    let intensity: Float
    /// `0...1` crispness.
    let sharpness: Float
}

/// AHAP-like event arrays for each `HapticPattern`.
enum HapticPatternLibrary {
    static func events(for pattern: HapticPattern) -> [HapticEvent] {
        switch pattern {
        case .sent:
            [.init(kind: .transient, time: 0, intensity: 0.6, sharpness: 0.8)]
        case .delivered:
            [
                .init(kind: .transient, time: 0, intensity: 0.45, sharpness: 0.6),
                .init(kind: .transient, time: 0.08, intensity: 0.45, sharpness: 0.6)
            ]
        case .read:
            [
                .init(kind: .transient, time: 0, intensity: 0.4, sharpness: 0.4),
                .init(kind: .transient, time: 0.07, intensity: 0.55, sharpness: 0.6),
                .init(kind: .transient, time: 0.14, intensity: 0.7, sharpness: 0.8)
            ]
        case .verified:
            [
                .init(kind: .transient, time: 0, intensity: 0.7, sharpness: 0.5),
                .init(kind: .continuous(duration: 0.25), time: 0.1, intensity: 0.5, sharpness: 0.3),
                .init(kind: .transient, time: 0.4, intensity: 1.0, sharpness: 0.9)
            ]
        case .warning:
            [
                .init(kind: .transient, time: 0, intensity: 0.9, sharpness: 0.9),
                .init(kind: .transient, time: 0.12, intensity: 0.9, sharpness: 0.9)
            ]
        case .keyChanged:
            [
                .init(kind: .continuous(duration: 0.18), time: 0, intensity: 0.8, sharpness: 0.2),
                .init(kind: .transient, time: 0.25, intensity: 1.0, sharpness: 1.0),
                .init(kind: .transient, time: 0.35, intensity: 1.0, sharpness: 1.0)
            ]
        case .whisperReveal:
            [.init(kind: .continuous(duration: 0.4), time: 0, intensity: 0.35, sharpness: 0.1)]
        case .capsuleUnlock:
            [
                .init(kind: .transient, time: 0, intensity: 0.5, sharpness: 0.3),
                .init(kind: .transient, time: 0.1, intensity: 0.7, sharpness: 0.5),
                .init(kind: .continuous(duration: 0.3), time: 0.2, intensity: 0.9, sharpness: 0.7)
            ]
        case .lock:
            [.init(kind: .transient, time: 0, intensity: 1.0, sharpness: 0.3)]
        }
    }
}
