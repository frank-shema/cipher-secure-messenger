import Foundation

/// Finds one-time codes: 4–8 digit runs within a few words of "code", "OTP", "verification", "2FA"
/// and similar, plus bare 6-digit runs (the overwhelmingly common TOTP length) even without context.
/// Forwarding a 2FA code is the classic account-takeover move, so a lower-confidence hint is worth it.
struct OneTimeCodeScanner: SensitiveContentScanner {
    static let minimumDigits = 4
    static let maximumDigits = 8
    /// How far (in characters) a keyword may sit from the digits to count as context.
    static let keywordProximity = 40

    func scan(_ text: String) -> [SensitiveFinding] {
        let keywordRanges = ScanText.codeKeywords.flatMap { ScanText.occurrences(of: $0, in: text) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wholeMessageIsDigits = !trimmed.isEmpty && trimmed.allSatisfy(\.isNumber)

        var findings: [SensitiveFinding] = []
        for run in Self.digitRuns(in: text) {
            let count = run.digits.count
            guard count >= Self.minimumDigits, count <= Self.maximumDigits else { continue }
            let hasContext = keywordRanges.contains { Self.isNear($0, run.range, in: text) }
            let confidence: Double
            if hasContext {
                confidence = count == 6 ? 0.92 : 0.85
            } else if wholeMessageIsDigits {
                confidence = 0.75
            } else if count == 6, !run.looksLikeDateOrTime {
                confidence = 0.6
            } else {
                continue
            }
            findings.append(SensitiveFinding(kind: .oneTimeCode, range: run.range, confidence: confidence))
        }
        return findings
    }

    private struct DigitRun {
        var digits: String
        var range: Range<String.Index>
        /// "2024" style years are excluded by length; a six-digit run glued to ":" "/" or "." on
        /// either side reads as a time or date and is skipped when there is no keyword context.
        var looksLikeDateOrTime: Bool
    }

    /// Contiguous digit runs, allowing a single internal space or dash so "123 456" is one code.
    private static func digitRuns(in text: String) -> [DigitRun] {
        var runs: [DigitRun] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            guard text[cursor].isNumber else {
                cursor = text.index(after: cursor)
                continue
            }
            var digits = ""
            var index = cursor
            var lastDigitEnd = cursor
            var separatorsSeen = 0
            while index < text.endIndex {
                let character = text[index]
                if let value = character.wholeNumberValue, character.isNumber {
                    digits.append(String(value))
                    index = text.index(after: index)
                    lastDigitEnd = index
                } else if ScanText.isGroupSeparator(character), separatorsSeen == 0, digits.count == 3 {
                    separatorsSeen += 1
                    index = text.index(after: index)
                } else {
                    break
                }
            }
            let range = cursor..<lastDigitEnd
            runs.append(DigitRun(digits: digits, range: range, looksLikeDateOrTime: neighboursDateLike(text, range)))
            cursor = lastDigitEnd
        }
        return runs
    }

    private static func neighboursDateLike(_ text: String, _ range: Range<String.Index>) -> Bool {
        let dateGlue: Set<Character> = [":", "/", "."]
        if range.lowerBound > text.startIndex, dateGlue.contains(text[text.index(before: range.lowerBound)]) {
            return true
        }
        if range.upperBound < text.endIndex, dateGlue.contains(text[range.upperBound]) {
            return true
        }
        return false
    }

    private static func isNear(_ keyword: Range<String.Index>, _ digits: Range<String.Index>, in text: String) -> Bool {
        if keyword.upperBound <= digits.lowerBound {
            return ScanText.distance(text, from: keyword.upperBound, to: digits.lowerBound) <= keywordProximity
        }
        if digits.upperBound <= keyword.lowerBound {
            return ScanText.distance(text, from: digits.upperBound, to: keyword.lowerBound) <= keywordProximity
        }
        return false
    }
}
