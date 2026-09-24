import Foundation

/// Domain failures raised by the use cases. Transport and crypto failures keep their own types
/// (`RetryableError` adopters, `CryptoError`) and are only wrapped where the caller needs Core context.
public enum CipherCoreError: Error, LocalizedError, Hashable, Sendable {
    case conversationNotFound(ConversationID)
    case contactNotFound(UserID)
    /// The conversation's contact has no pinned keys, so nothing can be sealed for them.
    case recipientKeysUnavailable(UserID)
    /// The directory could not supply keys for the other participant of an incoming envelope.
    case peerKeysUnavailable(UserID)
    /// The directory returned key material with the wrong length.
    case invalidKeyBundle(UserID)
    case messageNotFound(MessageID)
    /// Tampered content has no payload to re-seal.
    case messageNotRetryable(MessageID)
    case cannotMessageSelf
    case sealingFailed(CryptoError)

    public var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            CoreStrings.localized("error.core.conversationNotFound", default: "This conversation could not be found.")
        case .contactNotFound:
            CoreStrings.localized("error.core.contactNotFound", default: "This contact could not be found.")
        case .recipientKeysUnavailable:
            CoreStrings.localized("error.core.recipientKeysUnavailable", default: "This contact has not published encryption keys yet.")
        case .peerKeysUnavailable:
            CoreStrings.localized("error.core.peerKeysUnavailable", default: "The sender's keys could not be retrieved.")
        case .invalidKeyBundle:
            CoreStrings.localized("error.core.invalidKeyBundle", default: "The contact's published keys are invalid.")
        case .messageNotFound:
            CoreStrings.localized("error.core.messageNotFound", default: "This message could not be found.")
        case .messageNotRetryable:
            CoreStrings.localized("error.core.messageNotRetryable", default: "This message cannot be sent again.")
        case .cannotMessageSelf:
            CoreStrings.localized("error.core.cannotMessageSelf", default: "You cannot start a conversation with yourself.")
        case .sealingFailed:
            CoreStrings.localized("error.core.sealingFailed", default: "The message could not be encrypted.")
        }
    }
}
