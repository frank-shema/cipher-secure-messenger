import Foundation

/// One heuristic that finds a single kind of secret. Scanners are pure functions over the text so
/// the detector can run them in any order and merge the results deterministically.
protocol SensitiveContentScanner: Sendable {
    func scan(_ text: String) -> [SensitiveFinding]
}

/// Shared text helpers for the scanners.
enum ScanText {
    /// Words that mark a nearby digit run as a one-time code.
    static let codeKeywords: [String] = [
        "code", "otp", "verification", "verify", "2fa", "passcode", "one-time", "one time", "token",
        "authenticator", "confirmation"
    ]

    /// Words that introduce a password. `pin is` is matched as a phrase so "PIN" alone (which also
    /// appears in "pin the message") does not fire.
    static let passwordKeywords: [String] = [
        "password", "passwd", "passphrase", "pwd", "pass", "pin is", "pin:", "login is", "credentials"
    ]

    /// Tokens that follow a password keyword in ordinary prose and are never the secret itself.
    static let passwordStopWords: Set<String> = [
        "reset", "resets", "change", "changed", "changes", "manager", "protected", "for", "to", "the",
        "is", "was", "field", "please", "again", "wrong", "incorrect", "expired", "policy", "and", "or",
        "your", "my", "his", "her", "their", "our", "a", "an", "in", "on", "it", "that", "this", "with",
        "same", "new", "old", "strong", "weak", "required", "optional", "prompt", "hint", "recovery"
    ]

    /// Whether the character can appear inside a digit group separator for card numbers and IBANs.
    static func isGroupSeparator(_ character: Character) -> Bool {
        character == " " || character == "-" || character == "\u{00A0}"
    }

    /// Distance in characters between two indices, clamped to zero when reversed.
    static func distance(_ text: String, from: String.Index, to: String.Index) -> Int {
        guard from <= to else { return 0 }
        return text.distance(from: from, to: to)
    }

    /// Ranges of every case-insensitive occurrence of `keyword`.
    static func occurrences(of keyword: String, in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<text.endIndex) {
            result.append(found)
            searchStart = found.upperBound
        }
        return result
    }

    /// Lowercased, punctuation-trimmed form used for stop-word checks.
    static func normalizedWord(_ token: Substring) -> String {
        token.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }

    /// The character-class mix of a token: lowercase, uppercase, digits, symbols.
    static func characterClassCount(_ token: Substring) -> Int {
        var lower = false
        var upper = false
        var digit = false
        var symbol = false
        for character in token {
            if character.isLowercase {
                lower = true
            } else if character.isUppercase {
                upper = true
            } else if character.isNumber {
                digit = true
            } else {
                symbol = true
            }
        }
        return [lower, upper, digit, symbol].filter { $0 }.count
    }

    static func looksLikeURLOrEmail(_ token: Substring) -> Bool {
        token.contains("://") || token.contains("@") || token.lowercased().hasPrefix("www.")
    }
}
