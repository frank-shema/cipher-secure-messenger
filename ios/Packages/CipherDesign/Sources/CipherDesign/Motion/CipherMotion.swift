import SwiftUI

/// Cipher's motion vocabulary: a small, shared set of springs and durations so
/// every component moves with the same character.
public enum CipherMotion {
    /// Quick, decisive spring for taps, toggles and state flips.
    public static let snappy: Animation = .spring(response: 0.32, dampingFraction: 0.82)
    /// Soft spring for surfaces sliding, fading and settling into place.
    public static let gentle: Animation = .spring(response: 0.5, dampingFraction: 0.9)
    /// Playful overshoot reserved for celebratory moments (a seal cracking, an unlock).
    public static let bouncy: Animation = .spring(response: 0.45, dampingFraction: 0.6)

    /// Canonical durations, in seconds.
    public enum Duration {
        /// A single flash or blink.
        public static let instant: Double = 0.12
        /// Micro-interactions such as a hint appearing.
        public static let fast: Double = 0.2
        /// The default for reveals and transitions.
        public static let standard: Double = 0.4
        /// Long, cinematic sequences such as an envelope opening.
        public static let slow: Double = 0.7
    }

    /// The default animation, or `nil` when Reduce Motion is on.
    ///
    /// Pass the result straight into `withAnimation(_:)` or `.animation(_:value:)`;
    /// a `nil` animation applies state changes instantly.
    public static func reduced(_ reduceMotion: Bool) -> Animation? {
        snappy.reduced(reduceMotion)
    }
}

public extension Animation {
    /// This animation, or `nil` when Reduce Motion is on.
    func reduced(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }

    /// This animation, or a short crossfade when Reduce Motion is on.
    ///
    /// Use it where a state change must still be perceivable, but without movement.
    func crossfadeIfReduced(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: CipherMotion.Duration.fast) : self
    }
}
