#if DEBUG
import CipherCore
import Foundation

/// Echo's message store is rebuilt in memory on every launch, which is fine for its transcript but not
/// for the outgoing counter: `MessageRepository.nextCounter` promises monotonic counters across launches,
/// and a peer's `ReplayGuard` rejects a counter it has already accepted. This decorator forwards
/// everything to the in-memory store and reserves counters through `DemoBotMemory`, so Echo never hands
/// out a counter it used in an earlier process.
///
/// An actor, so two concurrent sends cannot read the same stored counter before either writes it back.
actor DemoBotMessageRepository: MessageRepository {
    private let base: any MessageRepository
    private let memory: DemoBotMemory

    init(base: any MessageRepository, memory: DemoBotMemory) {
        self.base = base
        self.memory = memory
    }

    /// The in-memory store keeps the counter monotonic within this launch; the memory keeps it monotonic
    /// across launches. Reserving the larger of the two and recording the successor satisfies both.
    func nextCounter(conversationId: ConversationID) async throws -> UInt64 {
        let fresh = try await base.nextCounter(conversationId: conversationId)
        return memory.reserveSendCounter(conversationId: conversationId, atLeast: fresh)
    }

    func upsert(_ message: Message) async throws {
        try await base.upsert(message)
    }

    func fetch(id: MessageID) async throws -> Message? {
        try await base.fetch(id: id)
    }

    func fetch(conversationId: ConversationID, senderId: UserID, counter: UInt64) async throws -> Message? {
        try await base.fetch(conversationId: conversationId, senderId: senderId, counter: counter)
    }

    func fetch(conversationId: ConversationID, limit: Int, before: Date?) async throws -> [Message] {
        try await base.fetch(conversationId: conversationId, limit: limit, before: before)
    }

    func knownIds(among ids: [MessageID]) async throws -> Set<MessageID> {
        try await base.knownIds(among: ids)
    }

    func observe(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        await base.observe(conversationId: conversationId)
    }

    func updateStatus(ids: [MessageID], status: MessageStatus, at: Date) async throws {
        try await base.updateStatus(ids: ids, status: status, at: at)
    }

    func markRead(conversationId: ConversationID, at: Date) async throws -> [MessageID] {
        try await base.markRead(conversationId: conversationId, at: at)
    }

    func delete(ids: [MessageID]) async throws {
        try await base.delete(ids: ids)
    }
}
#endif
