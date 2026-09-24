import Foundation
import SwiftData

/// The next outgoing counter for one conversation. Kept as its own row instead of being derived from
/// `max(StoredMessage.counter)` because deleting expired or unwanted messages must never let a counter
/// be handed out twice: each counter derives a distinct message key (PROTOCOL.md §4).
@Model
final class StoredSendCounter {
    @Attribute(.unique) var conversationId: UUID
    var nextCounter: Int64
    var updatedAt: Date

    init(conversationId: UUID, nextCounter: Int64, updatedAt: Date) {
        self.conversationId = conversationId
        self.nextCounter = nextCounter
        self.updatedAt = updatedAt
    }
}
