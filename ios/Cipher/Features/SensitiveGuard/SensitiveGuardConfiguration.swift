import CipherCore
import Foundation

/// Tunables for `SensitiveContentGuard`. Kept as a value so previews and a later test phase can dial
/// the debounce to zero and the thresholds to extremes without touching the guard itself.
struct SensitiveGuardConfiguration: Hashable, Sendable {
    /// How long a draft must sit unchanged before it is analysed. Typing bursts arrive every 50–100 ms,
    /// so a quarter second means one scan per pause rather than one per keystroke.
    var debounce: Duration
    /// Findings at or above this confidence skip the lexical review: an explicit "password: …" or a
    /// checksum-valid card number does not need a language model's second opinion.
    var lexicalReviewThreshold: Double
    /// A draft needs at least this many word tokens before it can be judged "prose".
    var minimumProseTokens: Int
    /// Share of tokens that must carry a dictionary word class for the draft to count as prose.
    var proseRatio: Double
    /// Passed through to Core's detector (scan length cap and minimum confidence).
    var detector: SensitiveContentDetector.Configuration

    init(
        debounce: Duration = .milliseconds(250),
        lexicalReviewThreshold: Double = 0.8,
        minimumProseTokens: Int = 6,
        proseRatio: Double = 0.6,
        detector: SensitiveContentDetector.Configuration = .default
    ) {
        self.debounce = max(debounce, .zero)
        self.lexicalReviewThreshold = min(max(lexicalReviewThreshold, 0), 1)
        self.minimumProseTokens = max(1, minimumProseTokens)
        self.proseRatio = min(max(proseRatio, 0), 1)
        self.detector = detector
    }

    static let `default` = SensitiveGuardConfiguration()

    /// No debounce, for callers that already coalesce keystrokes themselves (the chat composer does).
    static let immediate = SensitiveGuardConfiguration(debounce: .zero)
}
