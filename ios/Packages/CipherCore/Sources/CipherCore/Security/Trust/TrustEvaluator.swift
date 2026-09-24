import Foundation

/// Turns `TrustSignals` into a `TrustReport`. A weighted sum rather than a model: every point on
/// the meter must be explainable in one sentence, and the weights are the explanation.
public struct TrustEvaluator: Sendable {
    /// Weights and thresholds. Weights need not sum to 1; the score is normalised by their total so
    /// dropping a signal (say, on a build without attachments) does not cap the meter below 100%.
    public struct Weights: Hashable, Sendable {
        /// Verification is the only signal that defeats an impersonating relay, so it dominates.
        public var verification: Double
        /// Half of this bucket is granted to any stable key and the rest grows with key age.
        public var keyStability: Double
        public var disappearing: Double
        public var metadataStripping: Double
        /// Days after which a key counts as fully established.
        public var keyMaturityDays: Int
        /// Scores at or above this are `.medium`.
        public var mediumThreshold: Double
        /// Scores at or above this are `.high`.
        public var highThreshold: Double

        public init(
            verification: Double = 0.40,
            keyStability: Double = 0.20,
            disappearing: Double = 0.20,
            metadataStripping: Double = 0.20,
            keyMaturityDays: Int = 30,
            mediumThreshold: Double = 0.40,
            highThreshold: Double = 0.75
        ) {
            self.verification = max(0, verification)
            self.keyStability = max(0, keyStability)
            self.disappearing = max(0, disappearing)
            self.metadataStripping = max(0, metadataStripping)
            self.keyMaturityDays = max(1, keyMaturityDays)
            self.mediumThreshold = mediumThreshold
            self.highThreshold = max(highThreshold, mediumThreshold)
        }

        public static let `default` = Weights()

        var total: Double {
            verification + keyStability + disappearing + metadataStripping
        }
    }

    public var weights: Weights

    public init(weights: Weights = .default) {
        self.weights = weights
    }

    public func evaluate(_ signals: TrustSignals) -> TrustReport {
        let total = weights.total
        guard total > 0 else {
            return TrustReport(score: 0, level: .low, reasons: [])
        }
        let earned = verificationPoints(signals) + stabilityPoints(signals)
            + disappearingPoints(signals) + metadataPoints(signals)
        let score = min(max(earned / total, 0), 1)
        let reasons = Self.ordered(buildReasons(signals, total: total))
        return TrustReport(score: score, level: level(for: score, signals: signals), reasons: reasons)
    }

    // MARK: Points

    private func verificationPoints(_ signals: TrustSignals) -> Double {
        signals.verified ? weights.verification : 0
    }

    /// A key that changed recently earns nothing: until someone re-verifies, it is exactly what a
    /// substitution attack looks like. Otherwise half credit immediately, the rest as the key ages.
    private func stabilityPoints(_ signals: TrustSignals) -> Double {
        guard !signals.keyChangedRecently else { return 0 }
        return weights.keyStability * (0.5 + 0.5 * maturity(signals.keyAgeDays))
    }

    private func disappearingPoints(_ signals: TrustSignals) -> Double {
        signals.disappearingEnabled ? weights.disappearing : 0
    }

    private func metadataPoints(_ signals: TrustSignals) -> Double {
        signals.metadataStrippingEnabled ? weights.metadataStripping : 0
    }

    private func maturity(_ keyAgeDays: Int) -> Double {
        min(max(Double(keyAgeDays) / Double(weights.keyMaturityDays), 0), 1)
    }

    /// A recent key change caps the level at `.low` regardless of the arithmetic: two hygiene
    /// toggles must never paint a possibly hijacked conversation amber.
    private func level(for score: Double, signals: TrustSignals) -> TrustLevel {
        if signals.keyChangedRecently { return .low }
        if score >= weights.highThreshold { return .high }
        if score >= weights.mediumThreshold { return .medium }
        return .low
    }

    // MARK: Reasons

    private func buildReasons(_ signals: TrustSignals, total: Double) -> [TrustReason] {
        var reasons: [TrustReason] = []
        if signals.keyChangedRecently {
            reasons.append(TrustReason(kind: .keyChanged, improvesBy: weights.keyStability / total, action: .reviewKeyChange))
        } else {
            let unearned = weights.keyStability * 0.5 * (1 - maturity(signals.keyAgeDays))
            reasons.append(TrustReason(kind: unearned > 0 ? .keyFresh : .keyEstablished, improvesBy: unearned / total, action: nil))
        }
        reasons.append(signals.verified
            ? TrustReason(kind: .keysVerified, improvesBy: 0, action: nil)
            : TrustReason(kind: .keysUnverified, improvesBy: weights.verification / total, action: .verifyKeys))
        reasons.append(signals.disappearingEnabled
            ? TrustReason(kind: .disappearingOn, improvesBy: 0, action: nil)
            : TrustReason(kind: .disappearingOff, improvesBy: weights.disappearing / total, action: .enableDisappearing))
        reasons.append(signals.metadataStrippingEnabled
            ? TrustReason(kind: .metadataStrippingOn, improvesBy: 0, action: nil)
            : TrustReason(kind: .metadataStrippingOff, improvesBy: weights.metadataStripping / total, action: nil))
        return reasons
    }

    /// A key change leads whenever present, because it is what pins the level at `.low` and must be
    /// resolved before verification even makes sense. Then the most valuable open reason, and finally
    /// the satisfied ones in catalog order so the list is stable between evaluations.
    private static func ordered(_ reasons: [TrustReason]) -> [TrustReason] {
        let kindOrder = TrustReason.Kind.allCases
        return reasons.sorted { lhs, rhs in
            if (lhs.kind == .keyChanged) != (rhs.kind == .keyChanged) { return lhs.kind == .keyChanged }
            if lhs.improvesBy != rhs.improvesBy { return lhs.improvesBy > rhs.improvesBy }
            let lhsIndex = kindOrder.firstIndex(of: lhs.kind) ?? 0
            let rhsIndex = kindOrder.firstIndex(of: rhs.kind) ?? 0
            return lhsIndex < rhsIndex
        }
    }
}
