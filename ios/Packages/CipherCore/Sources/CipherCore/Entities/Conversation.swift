import Foundation

/// A 1:1 conversation as the local store sees it. The relay only knows participants and timestamps;
/// `lastMessage` and `unreadCount` are derived locally from decrypted content.
public struct Conversation: Hashable, Codable, Sendable, Identifiable {
    public var id: ConversationID
    public var contact: Contact
    public var lastMessage: Message?
    public var unreadCount: Int
    public var updatedAt: Date
    /// Default disappearing timer (seconds after read) applied to new outgoing messages.
    public var disappearingTimer: TimeInterval?

    public init(
        id: ConversationID,
        contact: Contact,
        lastMessage: Message?,
        unreadCount: Int,
        updatedAt: Date,
        disappearingTimer: TimeInterval?
    ) {
        self.id = id
        self.contact = contact
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
        self.disappearingTimer = disappearingTimer
    }
}
