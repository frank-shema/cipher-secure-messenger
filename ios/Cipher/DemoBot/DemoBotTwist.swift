#if DEBUG
import Foundation

/// How Echo mirrors a message that is not a command: the same words, bent a little, so a demo never
/// feels like talking to a wall. Chosen by the message's seed so a given message always gets the same
/// twist, which keeps screenshots and bug reports reproducible.
enum DemoBotTwist: CaseIterable {
    case reversedWords
    case mirrored
    case questioned
    case counted

    static func apply(to body: String, seed: UInt64) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).map { String($0) }
        let fitting = allCases.filter { $0.fits(words: words, text: trimmed) }
        let choice = fitting[Int(seed % UInt64(fitting.count))]
        return choice.render(words: words, text: trimmed)
    }

    /// `questioned` and `counted` always fit, so the candidate list is never empty.
    private func fits(words: [String], text: String) -> Bool {
        switch self {
        case .reversedWords: words.count >= 2
        case .mirrored: text.count <= 40 && words.count <= 6
        case .questioned, .counted: true
        }
    }

    private func render(words: [String], text: String) -> String {
        switch self {
        case .reversedWords:
            DemoBotPhrases.reversedWords(words.reversed().joined(separator: " "))
        case .mirrored:
            DemoBotPhrases.mirrored(String(text.reversed()))
        case .questioned:
            DemoBotPhrases.questioned(text.trimmingCharacters(in: .punctuationCharacters))
        case .counted:
            DemoBotPhrases.counted(words: words.count, characters: text.count)
        }
    }
}
#endif
