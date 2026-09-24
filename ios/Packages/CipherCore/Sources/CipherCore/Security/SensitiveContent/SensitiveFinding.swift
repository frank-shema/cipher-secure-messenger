import Foundation

/// What kind of secret a span of text looks like. Ordered by how costly a false negative is, which is
/// also the order used to break ties when two detectors claim overlapping text.
public enum SensitiveContentKind: String, Hashable, Codable, Sendable, CaseIterable {
    case password
    case cardNumber
    case iban
    case oneTimeCode

    /// Higher wins when findings overlap. A 16-digit Luhn-valid run inside "code: 4111 …" is a card
    /// number, not a one-time code, and a bank account beats a password guess.
    var precedence: Int {
        switch self {
        case .iban: 4
        case .cardNumber: 3
        case .password: 2
        case .oneTimeCode: 1
        }
    }
}

/// One span of a draft that looks like a secret. The range is in the coordinates of the scanned
/// string so the composer can highlight, redact or offer to send it as a whisper.
public struct SensitiveFinding: Hashable, Sendable {
    public var kind: SensitiveContentKind
    public var range: Range<String.Index>
    /// 0…1. Detectors are heuristics; the UI uses this to decide between a quiet chip and a blocking
    /// prompt rather than treating every hit as certain.
    public var confidence: Double

    public init(kind: SensitiveContentKind, range: Range<String.Index>, confidence: Double) {
        self.kind = kind
        self.range = range
        self.confidence = min(max(confidence, 0), 1)
    }

    /// The matched characters. Callers pass the same string that was scanned; indices from a
    /// different string are meaningless.
    public func matchedText(in text: String) -> Substring {
        guard range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex else {
            return Substring()
        }
        return text[range]
    }

    public func overlaps(_ other: SensitiveFinding) -> Bool {
        range.overlaps(other.range)
    }

    /// True when this finding should survive a collision with `other`.
    func outranks(_ other: SensitiveFinding) -> Bool {
        if kind.precedence != other.kind.precedence {
            return kind.precedence > other.kind.precedence
        }
        if confidence != other.confidence {
            return confidence > other.confidence
        }
        return range.lowerBound <= other.range.lowerBound
    }
}
