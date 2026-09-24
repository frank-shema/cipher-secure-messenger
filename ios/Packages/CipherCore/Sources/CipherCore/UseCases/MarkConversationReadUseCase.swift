import Foundation

/// Marks a conversation read locally and tells the sender over the socket.
public struct MarkConversationReadUseCase: Sendable {
    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let realtime: any RealtimeGateway
    private let clock: any Clock

    public init(
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        realtime: any RealtimeGateway,
        clock: any Clock = SystemClock()
    ) {
        self.messages = messages
        self.conversations = conversations
        self.realtime = realtime
        self.clock = clock
    }

    /// Returns the ids that became read. The local state wins: a failed receipt send is logged, not
    /// thrown, because the person did read the messages regardless of connectivity.
    public func execute(conversationId: ConversationID) async throws -> [MessageID] {
        let ids = try await messages.markRead(conversationId: conversationId, at: clock.now())
        try await conversations.setUnread(conversationId: conversationId, count: 0)
        guard !ids.isEmpty else { return ids }
        do {
            try await realtime.send(.receiptRead(conversationId: conversationId, messageIds: ids))
        } catch {
            let errorType = String(describing: type(of: error))
            CoreLog.useCases.notice("read receipt for \(ids.count) messages not sent: \(errorType, privacy: .public)")
        }
        return ids
    }
}
