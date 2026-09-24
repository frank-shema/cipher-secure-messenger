import Foundation
import NaturalLanguage

/// What `NLTagger` can say about a draft that helps separate secrets from ordinary words: which
/// tokens are names, which are dictionary words, and whether the whole draft reads as prose. The
/// tagger runs entirely on device; nothing leaves the process.
struct LexicalHints: Sendable {
    private let nameSpans: [Range<String.Index>]
    private let wordSpans: [Range<String.Index>]
    /// True when the draft has enough tokens and most of them carry a dictionary word class, which is
    /// what a sentence looks like and what a pasted credential does not.
    let readsAsProse: Bool

    private static let proseClasses: Set<NLTag> = [
        .noun, .verb, .adjective, .adverb, .pronoun, .determiner, .particle,
        .preposition, .conjunction, .interjection, .classifier, .idiom
    ]
    private static let nameClasses: Set<NLTag> = [.personalName, .placeName, .organizationName]
    private static let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

    init(text: String, minimumProseTokens: Int, proseRatio: Double) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        let whole = text.startIndex..<text.endIndex

        var words: [Range<String.Index>] = []
        var tokens = 0
        tagger.enumerateTags(in: whole, unit: .word, scheme: .lexicalClass, options: Self.options) { tag, range in
            tokens += 1
            if let tag, Self.proseClasses.contains(tag) {
                words.append(range)
            }
            return true
        }

        var names: [Range<String.Index>] = []
        tagger.enumerateTags(in: whole, unit: .word, scheme: .nameType, options: Self.options) { tag, range in
            if let tag, Self.nameClasses.contains(tag) {
                names.append(range)
            }
            return true
        }

        nameSpans = names
        wordSpans = words
        readsAsProse = tokens >= minimumProseTokens && Double(words.count) / Double(max(tokens, 1)) >= proseRatio
    }

    /// The span sits inside a token the tagger recognised as a person, place or organisation.
    func isName(_ range: Range<String.Index>) -> Bool {
        nameSpans.contains { $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound }
    }

    /// The span is a plain word (letters, apostrophes, hyphens) the tagger gave a dictionary class.
    /// Digits or symbols disqualify it: "Tr0ub4dor&3" is never a dictionary word whatever the tagger says.
    func isDictionaryWord(_ range: Range<String.Index>, in text: String) -> Bool {
        guard wordSpans.contains(where: { $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound }) else {
            return false
        }
        return text[range].allSatisfy { $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" }
    }
}
