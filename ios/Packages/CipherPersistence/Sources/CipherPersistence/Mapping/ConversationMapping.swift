import CipherCore
import Foundation

/// Assembles a domain `Conversation` from its row and the pieces stored alongside it. The pieces are
/// looked up by the store (they live in other tables) and handed in here so the shape of the result
/// is decided in exactly one place.
enum ConversationMapping {
    static func conversation(
        from row: StoredConversation,
        contact: Contact,
        lastMessage: Message?,
        settings: StoredConversationSettings?
    ) -> Conversation {
        Conversation(
            id: ConversationID(row.id),
            contact: contact,
            lastMessage: lastMessage,
            unreadCount: row.unreadCount,
            updatedAt: row.updatedAt,
            disappearingTimer: settings?.disappearingTimer
        )
    }

    /// Timers are stored only when meaningful; zero or negative means "off" rather than an error here
    /// because a full-snapshot upsert should be forgiving about a value the UI already normalised.
    static func normalizedTimer(_ timer: TimeInterval?) -> TimeInterval? {
        guard let timer, timer.isFinite, timer > 0 else { return nil }
        return timer
    }
}
