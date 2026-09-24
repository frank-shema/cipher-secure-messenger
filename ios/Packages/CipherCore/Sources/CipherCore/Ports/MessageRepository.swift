import Foundation

/// Local message store. Implementations are the source of truth for the chat UI; use cases write
/// optimistically and reconcile with the relay afterwards.
public protocol MessageRepository: Sendable {
    func upsert(_ message: Message) async throws
    func fetch(id: MessageID) async throws -> Message?
    /// Locates the message that first used a counter, for surfacing replays without duplicating them.
    func fetch(conversationId: ConversationID, senderId: UserID, counter: UInt64) async throws -> Message?
    /// Up to `limit` messages sent strictly before `before` (or the newest when nil), oldest first.
    func fetch(conversationId: ConversationID, limit: Int, before: Date?) async throws -> [Message]
    /// The subset of `ids` already stored; lets history sync stop as soon as it reaches known ground.
    func knownIds(among ids: [MessageID]) async throws -> Set<MessageID>
    /// Emits the full ordered message list on subscription and after every change.
    func observe(conversationId: ConversationID) async -> AsyncStream<[Message]>
    /// Applies `status` only where `MessageStatus.shouldAdvance(to:)` allows, so a late `delivered`
    /// receipt never downgrades a `read` message.
    func updateStatus(ids: [MessageID], status: MessageStatus, at: Date) async throws
    /// Reserves and returns the next outgoing counter for this conversation: strictly monotonic per
    /// (account, conversation), starting at 0, persisted across launches. Reuse would reuse a message key.
    func nextCounter(conversationId: ConversationID) async throws -> UInt64
    /// Marks incoming messages as read and returns the ids that changed, for the read receipt.
    func markRead(conversationId: ConversationID, at: Date) async throws -> [MessageID]
    func delete(ids: [MessageID]) async throws
}
