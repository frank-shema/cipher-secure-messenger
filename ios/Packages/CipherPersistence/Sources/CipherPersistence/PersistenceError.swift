import CipherCore
import Foundation

/// Every failure the persistence layer can surface. Payload strings are error *type names* only, never
/// descriptions, because a description could embed a decrypted body or a key.
public enum PersistenceError: Error, LocalizedError, Hashable, Sendable {
    /// Application Support could not be located or the account directory could not be created.
    case storageUnavailable(String)
    /// SwiftData refused to open the container (schema mismatch, corrupt file, disk full).
    case containerCreationFailed(String)
    case fetchFailed(String)
    case saveFailed(String)
    /// Domain content could not be serialised for storage.
    case encodingFailed(String)
    case conversationNotFound(ConversationID)
    case contactNotFound(UserID)
    case messageNotFound(MessageID)
    /// A disappearing timer must be positive; zero and negative values have no meaning.
    case invalidDisappearingTimer(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            PersistenceStrings.localized(
                "error.persistence.storageUnavailable",
                default: "Local storage is unavailable on this device."
            )
        case .containerCreationFailed:
            PersistenceStrings.localized(
                "error.persistence.containerCreationFailed",
                default: "Your local message database could not be opened."
            )
        case .fetchFailed:
            PersistenceStrings.localized(
                "error.persistence.fetchFailed",
                default: "Your messages could not be loaded."
            )
        case .saveFailed:
            PersistenceStrings.localized(
                "error.persistence.saveFailed",
                default: "Your changes could not be saved."
            )
        case .encodingFailed:
            PersistenceStrings.localized(
                "error.persistence.encodingFailed",
                default: "The message could not be prepared for storage."
            )
        case .conversationNotFound:
            PersistenceStrings.localized(
                "error.persistence.conversationNotFound",
                default: "This conversation could not be found."
            )
        case .contactNotFound:
            PersistenceStrings.localized(
                "error.persistence.contactNotFound",
                default: "This contact could not be found."
            )
        case .messageNotFound:
            PersistenceStrings.localized(
                "error.persistence.messageNotFound",
                default: "This message could not be found."
            )
        case .invalidDisappearingTimer:
            PersistenceStrings.localized(
                "error.persistence.invalidDisappearingTimer",
                default: "The disappearing message timer must be longer than zero."
            )
        }
    }

    /// Wraps an arbitrary error by type name only, so nothing sensitive from a description is kept.
    static func typeName(of error: any Error) -> String {
        String(describing: type(of: error))
    }
}
