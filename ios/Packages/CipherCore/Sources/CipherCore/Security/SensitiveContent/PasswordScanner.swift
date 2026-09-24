import Foundation

/// Finds passwords two ways: the token that follows a keyword such as "password:" or "pin is", and
/// high-entropy tokens in short messages (people paste a bare password far more often than they
/// announce it). Both are heuristics, so confidence reflects how explicit the evidence is.
struct PasswordScanner: SensitiveContentScanner {
    /// A message this short with one random-looking token is almost certainly a pasted credential.
    static let shortMessageCharacterLimit = 80
    static let shortMessageTokenLimit = 6
    static let entropyThresholdBits = 3.5

    func scan(_ text: String) -> [SensitiveFinding] {
        var findings = keywordFindings(in: text)
        findings.append(contentsOf: entropyFindings(in: text))
        return findings
    }

    // MARK: Keyword heuristics

    private func keywordFindings(in text: String) -> [SensitiveFinding] {
        var findings: [SensitiveFinding] = []
        for keyword in ScanText.passwordKeywords {
            for keywordRange in ScanText.occurrences(of: keyword, in: text) {
                guard Self.isWordBoundary(text, before: keywordRange.lowerBound) else { continue }
                if let finding = Self.secretFollowing(keywordRange, in: text) {
                    findings.append(finding)
                }
            }
        }
        return findings
    }

    /// Skips connector characters ("is", ":", "=", "-", "→") after the keyword and returns the next
    /// whitespace-delimited token when it does not read like ordinary prose.
    private static func secretFollowing(_ keyword: Range<String.Index>, in text: String) -> SensitiveFinding? {
        var index = keyword.upperBound
        var sawConnector = false
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                index = text.index(after: index)
            } else if character == ":" || character == "=" || character == "-" || character == "→" {
                sawConnector = true
                index = text.index(after: index)
            } else if !sawConnector, text[index...].lowercased().hasPrefix("is ") {
                sawConnector = true
                index = text.index(index, offsetBy: 2)
            } else {
                break
            }
        }
        guard index < text.endIndex else { return nil }
        let tokenEnd = text[index...].firstIndex(where: \.isWhitespace) ?? text.endIndex
        let token = text[index..<tokenEnd]
        let word = ScanText.normalizedWord(token)
        guard !word.isEmpty, !ScanText.passwordStopWords.contains(word), !ScanText.looksLikeURLOrEmail(token) else {
            return nil
        }
        if sawConnector {
            return SensitiveFinding(kind: .password, range: index..<tokenEnd, confidence: 0.9)
        }
        guard token.count >= 6, ScanText.characterClassCount(token) >= 2 else { return nil }
        return SensitiveFinding(kind: .password, range: index..<tokenEnd, confidence: 0.7)
    }

    private static func isWordBoundary(_ text: String, before index: String.Index) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return !(previous.isLetter || previous.isNumber)
    }

    // MARK: Entropy heuristics

    private func entropyFindings(in text: String) -> [SensitiveFinding] {
        guard text.count <= Self.shortMessageCharacterLimit else { return [] }
        let tokens = Self.tokens(in: text)
        guard !tokens.isEmpty, tokens.count <= Self.shortMessageTokenLimit else { return [] }
        return tokens.compactMap { token in
            guard let confidence = Self.entropyConfidence(for: text[token]) else { return nil }
            return SensitiveFinding(kind: .password, range: token, confidence: confidence)
        }
    }

    /// A pasted password is 8–64 characters, mixes at least three character classes (or two with
    /// high entropy), is not a URL, an email or a bare number, and is not a plain word.
    private static func entropyConfidence(for token: Substring) -> Double? {
        guard token.count >= 8, token.count <= 64 else { return nil }
        guard !ScanText.looksLikeURLOrEmail(token) else { return nil }
        guard !token.allSatisfy(\.isNumber) else { return nil }
        let classes = ScanText.characterClassCount(token)
        let entropy = Checksums.shannonEntropy(token)
        if classes >= 3 {
            return min(0.85, 0.65 + (entropy - 3.0) * 0.1)
        }
        if classes == 2, entropy >= entropyThresholdBits {
            return 0.6
        }
        return nil
    }

    private static func tokens(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while index < text.endIndex {
            if text[index].isWhitespace {
                index = text.index(after: index)
                continue
            }
            let end = text[index...].firstIndex(where: \.isWhitespace) ?? text.endIndex
            ranges.append(index..<end)
            index = end
        }
        return ranges
    }
}
