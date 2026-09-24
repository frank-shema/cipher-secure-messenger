import Foundation
import SwiftData

/// Per-conversation preferences kept apart from `StoredConversation` so they survive the conversation
/// row being rebuilt from a relay sync, and so a settings change never touches the row the inbox sorts by.
@Model
final class StoredConversationSettings {
    @Attribute(.unique) var conversationId: UUID
    /// Seconds after read until new outgoing messages disappear; nil means off.
    var disappearingTimer: Double?
    var updatedAt: Date

    init(conversationId: UUID, disappearingTimer: Double?, updatedAt: Date) {
        self.conversationId = conversationId
        self.disappearingTimer = disappearingTimer
        self.updatedAt = updatedAt
    }
}
