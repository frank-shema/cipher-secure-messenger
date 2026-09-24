import Foundation

/// A conversation as the relay describes it: participants and clocks, nothing about content.
public struct RemoteConversation: Hashable, Sendable {
    public var id: ConversationID
    public var participants: [User]
    public var createdAt: Date
    public var lastMessageAt: Date?

    public init(id: ConversationID, participants: [User], createdAt: Date, lastMessageAt: Date?) {
        self.id = id
        self.participants = participants
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
    }

    /// The other participant of this 1:1 conversation.
    public func counterpart(of userId: UserID) -> User? {
        participants.first { $0.id != userId }
    }
}

/// One page of history. Items are newest first, as the relay returns them.
public struct MessagePage: Hashable, Sendable {
    public var items: [StoredEnvelope]
    public var hasMore: Bool

    public init(items: [StoredEnvelope], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }
}

/// The relay's answer to a send. A duplicate id returns the stored status, which is what makes
/// retries idempotent.
public struct MessageAck: Hashable, Sendable {
    public var id: MessageID
    public var status: DeliveryStatus
    public var createdAt: Date

    public init(id: MessageID, status: DeliveryStatus, createdAt: Date) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
    }
}

/// `/api/v1/conversations/*` (PROTOCOL.md §1.3).
public protocol ConversationGateway: Sendable {
    /// Deterministic per pair of users: the same two people always resolve to the same conversation.
    func createOrGet(participantId: UserID) async throws -> RemoteConversation
    func list() async throws -> [RemoteConversation]
    /// `before` excludes items whose relay `createdAt` is at or after it; nil starts from the newest.
    func fetchMessages(conversationId: ConversationID, before: Date?, limit: Int) async throws -> MessagePage
    func send(_ envelope: Envelope) async throws -> MessageAck
}
