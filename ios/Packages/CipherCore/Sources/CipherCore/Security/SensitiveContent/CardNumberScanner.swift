import Foundation

/// Finds payment card numbers: 13–19 digits, optionally grouped by spaces or dashes, that pass Luhn.
/// Written as a hand-rolled scan instead of a regex so grouping rules stay explicit and the same
/// code handles "4111-1111-1111-1111" and "4111 1111 1111 1111" identically.
struct CardNumberScanner: SensitiveContentScanner {
    static let minimumDigits = 13
    static let maximumDigits = 19

    func scan(_ text: String) -> [SensitiveFinding] {
        var findings: [SensitiveFinding] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            guard text[cursor].isNumber else {
                cursor = text.index(after: cursor)
                continue
            }
            let run = Self.digitRun(in: text, from: cursor)
            if run.digits.count >= Self.minimumDigits,
               run.digits.count <= Self.maximumDigits,
               Checksums.passesLuhn(run.digits) {
                findings.append(SensitiveFinding(
                    kind: .cardNumber,
                    range: run.range,
                    confidence: Self.confidence(for: run.digits)
                ))
            }
            cursor = run.range.upperBound
        }
        return findings
    }

    /// Consumes digits and single group separators starting at `start`. Two separators in a row or
    /// a trailing separator end the run, and the range excludes any trailing separator.
    private static func digitRun(in text: String, from start: String.Index) -> (digits: String, range: Range<String.Index>) {
        var digits = ""
        var lastDigitEnd = start
        var index = start
        var previousWasSeparator = false
        while index < text.endIndex {
            let character = text[index]
            if character.isNumber, let value = character.wholeNumberValue {
                digits.append(String(value))
                index = text.index(after: index)
                lastDigitEnd = index
                previousWasSeparator = false
            } else if ScanText.isGroupSeparator(character), !previousWasSeparator {
                previousWasSeparator = true
                index = text.index(after: index)
            } else {
                break
            }
        }
        return (digits, start..<lastDigitEnd)
    }

    /// Luhn alone is a 1-in-10 filter, so a recognisable issuer prefix raises confidence.
    private static func confidence(for digits: String) -> Double {
        hasKnownIssuerPrefix(digits) ? 0.97 : 0.85
    }

    private static func hasKnownIssuerPrefix(_ digits: String) -> Bool {
        guard let first = digits.first?.wholeNumberValue else { return false }
        let firstTwo = Int(digits.prefix(2)) ?? 0
        let firstFour = Int(digits.prefix(4)) ?? 0
        switch first {
        case 4:
            return digits.count == 13 || digits.count == 16 || digits.count == 19
        case 5:
            return (51...55).contains(firstTwo) && digits.count == 16
        case 2:
            return (2_221...2_720).contains(firstFour) && digits.count == 16
        case 3:
            return (firstTwo == 34 || firstTwo == 37) && digits.count == 15
        case 6:
            return (firstFour == 6_011 || firstTwo == 65) && digits.count == 16
        default:
            return false
        }
    }
}
