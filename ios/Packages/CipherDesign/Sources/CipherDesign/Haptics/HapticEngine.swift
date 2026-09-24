import Foundation

/// Plays semantic haptic patterns. Implementations must be safe to call from
/// the main actor and should never throw to callers.
@MainActor
public protocol HapticEngine: AnyObject {
    /// Plays `pattern`, falling back silently when haptics are unavailable.
    func play(_ pattern: HapticPattern)
}

/// A no-op engine for previews, tests and platforms without haptics.
@MainActor
public final class NoopHapticEngine: HapticEngine {
    /// Patterns requested so far, useful in tests.
    public private(set) var played: [HapticPattern] = []

    /// Creates a no-op engine.
    public init() {}

    public func play(_ pattern: HapticPattern) {
        played.append(pattern)
    }
}
