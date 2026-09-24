import CipherCore
import Foundation

/// Watches the composer for secrets and suggests sending them as view-once with a short auto-delete.
///
/// Every step runs on this device: Core's scanners (keyword, entropy, Luhn, IBAN mod-97), Foundation's
/// `NSDataDetector` and the `NaturalLanguage` tagger are all local frameworks with no network path.
/// A draft never leaves the process because of the guard, and the guard never logs a character of it.
///
/// The pipeline, in order:
/// 1. Debounce: a call that is superseded within `configuration.debounce` yields nothing, so a typing
///    burst costs one scan. Analysis runs on the actor's executor, never on the main actor.
/// 2. Detect: Core's `SensitiveContentDetector` produces non-overlapping findings.
/// 3. Veto: findings inside a link are dropped for every kind; findings inside a phone number are
///    dropped for codes and passwords (card and IBAN hits are checksum-validated and keep their say).
/// 4. Lexical review, for findings below `lexicalReviewThreshold` only: a token the tagger recognises
///    as a name or a plain dictionary word is not a password, and a bare six-digit number inside a
///    fluent sentence is a quantity, not a code.
/// 5. Rank: the most severe surviving finding becomes the suggestion.
actor SensitiveContentGuard: SensitiveContentDetecting {
    private let configuration: SensitiveGuardConfiguration
    private let detector: SensitiveContentDetector
    private let exclusions: DataDetectorExclusions
    private let isEnabled: @Sendable () -> Bool
    private var latestTicket: UInt64 = 0

    /// - Parameters:
    ///   - configuration: Debounce and thresholds; `.immediate` when the caller already debounces.
    ///   - isEnabled: Read on every call so the Settings toggle takes effect on the next keystroke.
    init(configuration: SensitiveGuardConfiguration = .default, isEnabled: @escaping @Sendable () -> Bool = { true }) {
        self.configuration = configuration
        self.detector = SensitiveContentDetector(configuration: configuration.detector)
        self.exclusions = DataDetectorExclusions()
        self.isEnabled = isEnabled
    }

    /// `SensitiveContentDetecting`: the kind alone, for the chat composer's existing port.
    func detect(in text: String) async -> SensitiveKind? {
        await suggestion(for: text)?.kind
    }

    /// The full verdict, or nil when the guard is off, the draft is clean, or a newer draft superseded
    /// this one during the debounce window.
    func suggestion(for text: String) async -> SensitiveSuggestion? {
        guard isEnabled() else { return nil }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        latestTicket &+= 1
        let ticket = latestTicket
        if configuration.debounce > .zero {
            do {
                try await Task.sleep(for: configuration.debounce)
            } catch {
                return nil
            }
            guard ticket == latestTicket else { return nil }
        }
        return analyse(text)
    }

    // MARK: Pipeline

    private func analyse(_ text: String) -> SensitiveSuggestion? {
        let findings = detector.detect(in: text)
        guard !findings.isEmpty else { return nil }
        let spans = exclusions.spans(in: text)
        let needsLexicalReview = findings.contains { $0.confidence < configuration.lexicalReviewThreshold }
        let hints = needsLexicalReview
            ? LexicalHints(text: text, minimumProseTokens: configuration.minimumProseTokens,
                           proseRatio: configuration.proseRatio)
            : nil
        let kept = findings.filter { keep($0, in: text, spans: spans, hints: hints) }
        let vetoed = findings.count - kept.count
        guard let best = kept.max(by: Self.lessSevere) else {
            SensitiveGuardLog.guardian.debug("guard vetoed \(vetoed, privacy: .public) finding(s); nothing to suggest")
            return nil
        }
        let kind = best.kind.rawValue
        SensitiveGuardLog.guardian.debug(
            "guard suggests kind=\(kind, privacy: .public) kept=\(kept.count, privacy: .public) vetoed=\(vetoed, privacy: .public)"
        )
        return SensitiveSuggestion(kind: best.kind, confidence: best.confidence)
    }

    private func keep(
        _ finding: SensitiveFinding,
        in text: String,
        spans: DataDetectorExclusions.Spans,
        hints: LexicalHints?
    ) -> Bool {
        if spans.coversLink(finding.range) {
            return false
        }
        if finding.kind == .oneTimeCode || finding.kind == .password, spans.coversPhoneNumber(finding.range) {
            return false
        }
        guard finding.confidence < configuration.lexicalReviewThreshold, let hints else {
            return true
        }
        if hints.isName(finding.range) || hints.isDictionaryWord(finding.range, in: text) {
            return false
        }
        if finding.kind == .oneTimeCode, hints.readsAsProse {
            return false
        }
        return true
    }

    /// Severity first, then confidence, so `max(by:)` picks the finding a person would most regret.
    private static func lessSevere(_ lhs: SensitiveFinding, _ rhs: SensitiveFinding) -> Bool {
        let left = SensitiveGuardCopy.severity(of: lhs.kind)
        let right = SensitiveGuardCopy.severity(of: rhs.kind)
        if left != right { return left < right }
        return lhs.confidence < rhs.confidence
    }
}
