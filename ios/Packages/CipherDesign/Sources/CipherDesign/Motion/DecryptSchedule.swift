import Foundation

/// A deterministic, left-to-right timing plan for resolving cipher glyphs into plaintext.
///
/// Each character has a start time (when it begins cycling quickly) and a resolve
/// time (when it snaps to its plaintext value and flashes). Start times increase
/// monotonically with the character index, so the reveal always reads left to right.
public struct DecryptSchedule: Sendable, Equatable {
    /// Which visual state a character is in at a given moment.
    public enum CharacterState: Sendable, Equatable {
        /// Still hidden behind a slowly drifting glyph.
        case cipher
        /// Cycling rapidly through glyphs just before resolving.
        case resolving
        /// Resolved to plaintext and glowing; `progress` runs 0 → 1 over the flash.
        case flashing(progress: Double)
        /// Resolved to plaintext with no highlight.
        case plain
    }

    /// Number of characters covered by the schedule.
    public let count: Int
    /// Total time from the first character starting to the last resolving.
    public let duration: Double
    /// How long each character spends in the rapid-cycling state.
    public let resolveDuration: Double
    /// Duration of the highlight after a character resolves.
    public let flashDuration: Double

    /// Creates a schedule for `count` characters resolving over `duration` seconds.
    public init(count: Int, duration: Double = 0.4, flashDuration: Double = 0.14) {
        self.count = max(count, 0)
        self.duration = max(duration, 0)
        self.resolveDuration = min(self.duration * 0.35, self.duration)
        self.flashDuration = max(flashDuration, 0)
    }

    /// Delay between consecutive characters starting to resolve.
    public var stagger: Double {
        count > 1 ? (duration - resolveDuration) / Double(count - 1) : 0
    }

    /// Time at which the whole effect, including the last flash, has finished.
    public var totalDuration: Double { duration + flashDuration }

    /// Elapsed time at which the character at `index` begins cycling rapidly.
    public func start(of index: Int) -> Double {
        Double(min(max(index, 0), max(count - 1, 0))) * stagger
    }

    /// Elapsed time at which the character at `index` snaps to plaintext.
    public func resolveTime(of index: Int) -> Double {
        start(of: index) + resolveDuration
    }

    /// The character's visual state at `elapsed` seconds into the reveal.
    public func state(of index: Int, at elapsed: Double) -> CharacterState {
        let resolved = resolveTime(of: index)
        if elapsed < start(of: index) { return .cipher }
        if elapsed < resolved { return .resolving }
        let sinceResolve = elapsed - resolved
        if flashDuration > 0, sinceResolve < flashDuration {
            return .flashing(progress: sinceResolve / flashDuration)
        }
        return .plain
    }
}
