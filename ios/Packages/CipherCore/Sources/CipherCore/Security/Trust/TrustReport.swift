import Foundation

/// Coarse bucket for the Trust Meter's colour and headline. Three levels keep the meter honest:
/// finer gradations would suggest a precision the heuristics do not have.
public enum TrustLevel: String, Hashable, Codable, Sendable, CaseIterable, Comparable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    public static func < (lhs: TrustLevel, rhs: TrustLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Something the person can do right now to raise the score. Each case maps to one screen the UI
/// can route to; anything that is not actionable (key age) is expressed as a reason without an action.
public enum TrustAction: String, Hashable, Codable, Sendable, CaseIterable {
    case verifyKeys
    case enableDisappearing
    case reviewKeyChange
}

/// One line of the Trust Meter breakdown. Strings are exposed as catalog keys so the app target
/// owns the wording and translations; `improvesBy` lets the UI say "+40%" next to the action.
public struct TrustReason: Hashable, Sendable, Identifiable {
    public enum Kind: String, Hashable, Codable, Sendable, CaseIterable {
        case keyChanged
        case keysUnverified
        case keysVerified
        case keyFresh
        case keyEstablished
        case disappearingOff
        case disappearingOn
        case metadataStrippingOff
        case metadataStrippingOn
    }

    public var kind: Kind
    /// Key of the short headline, e.g. `trust.reason.keysUnverified.title`.
    public var titleKey: String
    /// Key of the one-sentence explanation, e.g. `trust.reason.keysUnverified.detail`.
    public var detailKey: String
    /// How much of the 0…1 score this reason is currently costing; zero when the signal is satisfied.
    public var improvesBy: Double
    public var action: TrustAction?

    public init(kind: Kind, improvesBy: Double, action: TrustAction?) {
        self.kind = kind
        self.titleKey = "trust.reason.\(kind.rawValue).title"
        self.detailKey = "trust.reason.\(kind.rawValue).detail"
        self.improvesBy = min(max(improvesBy, 0), 1)
        self.action = action
    }

    public var id: Kind {
        kind
    }

    /// True when this reason describes something already in the person's favour.
    public var isSatisfied: Bool {
        improvesBy == 0
    }
}

/// The evaluator's verdict for one conversation.
public struct TrustReport: Hashable, Sendable {
    /// 0…1, where 1 means every signal is in the person's favour.
    public var score: Double
    public var level: TrustLevel
    /// Ordered with the most valuable unsatisfied reason first, then the satisfied ones.
    public var reasons: [TrustReason]

    public init(score: Double, level: TrustLevel, reasons: [TrustReason]) {
        self.score = min(max(score, 0), 1)
        self.level = level
        self.reasons = reasons
    }

    /// Whole-number percentage for the meter label.
    public var percent: Int {
        Int((score * 100).rounded())
    }

    /// The single action that would raise the score most; nil when nothing is left to do.
    public var recommendedAction: TrustAction? {
        reasons.lazy.filter { !$0.isSatisfied }.compactMap(\.action).first
    }

    /// Reasons still costing points, most valuable first.
    public var openReasons: [TrustReason] {
        reasons.filter { !$0.isSatisfied }
    }
}
