#if DEBUG
import Foundation

/// The words Echo treats as orders rather than conversation.
enum DemoBotCommand: Hashable, Sendable, CaseIterable {
    case help
    case photo
    case capsule
    case whisper
    case disappear
    case ping
    case greeting

    /// Recognises a command typed on its own ("photo", "Photo!", "/photo", "time capsule"). A command
    /// word inside a sentence is conversation, not an order: "I love this photo" gets mirrored, not
    /// answered with a picture.
    init?(text: String) {
        var normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = normalized.first, first == "/" {
            normalized.removeFirst()
        }
        normalized = normalized.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        let collapsed = normalized.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let match = Self.allCases.first(where: { $0.aliases.contains(collapsed) }) else { return nil }
        self = match
    }

    private var aliases: Set<String> {
        switch self {
        case .help: ["help", "commands", "menu", "what can you do"]
        case .photo: ["photo", "pic", "picture", "image", "selfie"]
        case .capsule: ["capsule", "time capsule", "timecapsule"]
        case .whisper: ["whisper", "psst"]
        case .disappear: ["disappear", "disappearing", "timer"]
        case .ping: ["ping"]
        case .greeting: ["hi", "hello", "hey", "yo", "hola", "hi echo", "hello echo", "hey echo"]
        }
    }
}
#endif
