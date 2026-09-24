import CipherCore
import Foundation

/// The per-message switches a person can flip in the composer. They reset after every send because
/// each of them changes what the recipient can do with the message, and sticky defaults would make
/// it far too easy to send a whisper or a time capsule by accident.
struct ComposerOptions: Hashable, Sendable {
    /// Blurred until the recipient holds the bubble; never previewed in the inbox.
    var whisper = false
    /// The recipient can open the attachment once; only meaningful with a staged image.
    var viewOnce = false
    /// Time Capsule: the recipient keeps the message sealed until this instant.
    var unlockAt: Date?
    /// Seconds after read until both sides delete, set by the sensitive-content suggestion. It wins
    /// over the conversation-level timer because the person accepted it for this very message.
    var suggestedDisappearAfter: TimeInterval?

    var isTimeCapsule: Bool { unlockAt != nil }

    /// Anything on means the composer shows its accent state and the send button should say so.
    var isAnyEnabled: Bool { whisper || viewOnce || isTimeCapsule }

    func flags(conversationTimer: TimeInterval?) -> MessageFlags {
        MessageFlags(
            viewOnce: viewOnce,
            whisper: whisper,
            disappearAfter: suggestedDisappearAfter ?? conversationTimer,
            unlockAt: unlockAt
        )
    }
}

/// Errors the chat screen raises itself. Transport and crypto failures come from Core already typed.
enum ChatError: Error, LocalizedError, Hashable, Sendable {
    case attachmentsUnavailable
    case envelopeUnavailable
    case nothingToSend

    var errorDescription: String? {
        switch self {
        case .attachmentsUnavailable:
            String(localized: "chat.error.attachmentsUnavailable", defaultValue: "Attachments are not available in this build.")
        case .envelopeUnavailable:
            String(localized: "chat.error.envelopeUnavailable", defaultValue: "The stored envelope for this message is missing.")
        case .nothingToSend:
            String(localized: "chat.error.nothingToSend", defaultValue: "Type a message or attach a file first.")
        }
    }
}
