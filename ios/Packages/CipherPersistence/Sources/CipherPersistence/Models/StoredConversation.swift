import Foundation
import SwiftData

/// A 1:1 conversation row. The contact and the last message are referenced by id rather than as
/// SwiftData relationships so deleting a message or re-pinning a contact never cascades into the
/// conversation, and so every read maps through one code path (`ConversationMapping`).
@Model
final class StoredConversation {
    @Attribute(.unique) var id: UUID
    var contactId: UUID
    var lastMessageId: UUID?
    var unreadCount: Int
    var updatedAt: Date
    var createdAt: Date

    init(id: UUID, contactId: UUID, lastMessageId: UUID?, unreadCount: Int, updatedAt: Date, createdAt: Date) {
        self.id = id
        self.contactId = contactId
        self.lastMessageId = lastMessageId
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
}
