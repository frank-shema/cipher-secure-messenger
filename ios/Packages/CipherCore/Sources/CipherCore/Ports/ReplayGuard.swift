import Foundation

/// Remembers `(senderId, conversationId, counter)` triples that were successfully opened, so a
/// re-sent envelope with a valid signature cannot be shown twice (PROTOCOL.md §4). Persisted, because a
/// replay that survives a relaunch is exactly the kind an attacker would try.
public protocol ReplayGuard: Sendable {
    func isReplay(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws -> Bool
    func markSeen(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws
}
