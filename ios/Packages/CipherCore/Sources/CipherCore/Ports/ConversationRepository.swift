import Foundation

public protocol ConversationRepository: Sendable {
    func upsert(_ conversation: Conversation) async throws
    func fetch(id: ConversationID) async throws -> Conversation?
    func fetchAll() async throws -> [Conversation]
    /// Emits all conversations, most recently updated first, on subscription and after every change.
    func observeAll() async -> AsyncStream<[Conversation]>
    /// Sets `lastMessage` and moves `updatedAt` forward to the message's effective timestamp.
    func updateLastMessage(conversationId: ConversationID, message: Message) async throws
    func setUnread(conversationId: ConversationID, count: Int) async throws
    func delete(id: ConversationID) async throws
}
