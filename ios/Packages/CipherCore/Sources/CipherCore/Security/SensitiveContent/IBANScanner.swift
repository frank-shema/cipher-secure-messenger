import Foundation

/// Finds IBANs: two letters, two check digits, then 11–30 alphanumerics, optionally grouped in fours,
/// validated with ISO 13616 mod-97. A country length table cuts the remaining false positives for the
/// common countries without refusing unknown ones.
struct IBANScanner: SensitiveContentScanner {
    static let minimumLength = 15
    static let maximumLength = 34

    /// Official IBAN lengths for frequently seen countries. Unknown countries are accepted on the
    /// checksum alone, because refusing them would hide real account numbers from users abroad.
    static let knownLengths: [String: Int] = [
        "AT": 20, "BE": 16, "BG": 22, "CH": 21, "CY": 28, "CZ": 24, "DE": 22, "DK": 18, "EE": 20,
        "ES": 24, "FI": 18, "FR": 27, "GB": 22, "GR": 27, "HR": 21, "HU": 28, "IE": 22, "IS": 26,
        "IT": 27, "LI": 21, "LT": 20, "LU": 20, "LV": 21, "MC": 27, "MT": 31, "NL": 18, "NO": 15,
        "PL": 28, "PT": 25, "RO": 24, "SE": 24, "SI": 19, "SK": 24, "SM": 27, "TR": 26, "AE": 23,
        "SA": 24, "QA": 29, "IL": 23, "TN": 24, "MA": 28, "EG": 29, "BR": 29, "PK": 24, "KZ": 20
    ]

    func scan(_ text: String) -> [SensitiveFinding] {
        var findings: [SensitiveFinding] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            guard Self.isCandidateStart(text, at: cursor) else {
                cursor = text.index(after: cursor)
                continue
            }
            let run = Self.alphanumericRun(in: text, from: cursor)
            if let finding = Self.finding(for: run.normalized, range: run.range) {
                findings.append(finding)
                cursor = run.range.upperBound
            } else {
                cursor = text.index(after: cursor)
            }
        }
        return findings
    }

    /// An IBAN starts with two ASCII letters followed by two digits, at a word boundary.
    private static func isCandidateStart(_ text: String, at index: String.Index) -> Bool {
        if index > text.startIndex {
            let previous = text[text.index(before: index)]
            if previous.isLetter || previous.isNumber { return false }
        }
        var probe = index
        for position in 0..<4 {
            guard probe < text.endIndex else { return false }
            let character = text[probe]
            if position < 2 {
                guard character.isLetter, character.isASCII else { return false }
            } else {
                guard character.isNumber else { return false }
            }
            probe = text.index(after: probe)
        }
        return true
    }

    private static func alphanumericRun(in text: String, from start: String.Index) -> (normalized: String, range: Range<String.Index>) {
        var normalized = ""
        var lastEnd = start
        var index = start
        var previousWasSeparator = false
        while index < text.endIndex, normalized.count < maximumLength {
            let character = text[index]
            if character.isASCII, character.isLetter || character.isNumber {
                normalized.append(character.uppercased())
                index = text.index(after: index)
                lastEnd = index
                previousWasSeparator = false
            } else if ScanText.isGroupSeparator(character), !previousWasSeparator {
                previousWasSeparator = true
                index = text.index(after: index)
            } else {
                break
            }
        }
        return (normalized, start..<lastEnd)
    }

    private static func finding(for normalized: String, range: Range<String.Index>) -> SensitiveFinding? {
        guard normalized.count >= minimumLength, normalized.count <= maximumLength else { return nil }
        let country = String(normalized.prefix(2))
        if let expected = knownLengths[country], expected != normalized.count {
            return nil
        }
        guard Checksums.passesIBANMod97(normalized) else { return nil }
        let confidence = knownLengths[country] == nil ? 0.8 : 0.98
        return SensitiveFinding(kind: .iban, range: range, confidence: confidence)
    }
}
