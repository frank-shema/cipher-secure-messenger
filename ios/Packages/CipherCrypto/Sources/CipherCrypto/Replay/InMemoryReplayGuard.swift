import CipherCore
import Foundation

/// Replay guard that forgets everything on relaunch. Meant for previews, the DEBUG demo companion and
/// tests; the app uses the persisted implementation from CipherPersistence so a replay across a
/// restart is still caught.
public actor InMemoryReplayGuard: ReplayGuard {
    private struct Key: Hashable {
        let senderId: UserID
        let conversationId: ConversationID
        let counter: UInt64
    }

    private var seen: Set<Key> = []

    public init() {}

    public func isReplay(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws -> Bool {
        seen.contains(Key(senderId: senderId, conversationId: conversationId, counter: counter))
    }

    public func markSeen(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws {
        seen.insert(Key(senderId: senderId, conversationId: conversationId, counter: counter))
    }

    /// Number of remembered triples; handy for previews that show replay statistics.
    public var count: Int {
        seen.count
    }
}
