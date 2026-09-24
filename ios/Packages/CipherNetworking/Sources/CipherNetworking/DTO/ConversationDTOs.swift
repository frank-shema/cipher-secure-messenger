import CipherCore
import Foundation

/// `POST /conversations` body (PROTOCOL.md §1.3).
public struct CreateConversationRequest: Hashable, Encodable, Sendable {
    public var participantId: UserID

    public init(participantId: UserID) {
        self.participantId = participantId
    }
}

/// One entry of `Conversation.participants`. The relay spells the id `userId` here but `id` in
/// `AuthResponse.user`, which is why this is not `UserDTO`.
public struct ParticipantDTO: Hashable, Decodable, Sendable {
    public var userId: UserID
    public var username: String
    public var displayName: String

    public init(userId: UserID, username: String, displayName: String) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
    }

    public func toDomain() -> User {
        User(id: userId, username: username, displayName: displayName)
    }
}

/// `Conversation` (PROTOCOL.md §1.3).
public struct ConversationDTO: Hashable, Decodable, Sendable, APIResponse {
    public var id: ConversationID
    public var participants: [ParticipantDTO]
    public var createdAt: Int64
    public var lastMessageAt: Int64?

    public init(id: ConversationID, participants: [ParticipantDTO], createdAt: Int64, lastMessageAt: Int64?) {
        self.id = id
        self.participants = participants
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
    }

    public func toDomain() -> RemoteConversation {
        RemoteConversation(
            id: id,
            participants: participants.map { $0.toDomain() },
            createdAt: Date(epochMillis: createdAt),
            lastMessageAt: lastMessageAt.map { Date(epochMillis: $0) }
        )
    }
}

/// `MessageAck` (PROTOCOL.md §1.3).
public struct MessageAckDTO: Hashable, Decodable, Sendable, APIResponse {
    public var id: MessageID
    public var status: DeliveryStatus
    public var createdAt: Int64

    public init(id: MessageID, status: DeliveryStatus, createdAt: Int64) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
    }

    public func toDomain() -> MessageAck {
        MessageAck(id: id, status: status, createdAt: Date(epochMillis: createdAt))
    }
}

/// `MessagePage` (PROTOCOL.md §1.3). Items decode straight into Core's `StoredEnvelope`, whose Codable
/// conformance already speaks the exact wire keys, so there is no separate envelope DTO to drift.
public struct MessagePageDTO: Hashable, Decodable, Sendable, APIResponse {
    public var items: [StoredEnvelope]
    public var hasMore: Bool

    public init(items: [StoredEnvelope], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }

    public func toDomain() -> MessagePage {
        MessagePage(items: items, hasMore: hasMore)
    }
}

/// `GET /conversations` answers with a bare JSON array; this wrapper decodes it without a keyed
/// container so the response type can still conform to `APIResponse`.
public struct ConversationListDTO: Hashable, Decodable, Sendable, APIResponse {
    public var conversations: [ConversationDTO]

    public init(conversations: [ConversationDTO]) {
        self.conversations = conversations
    }

    public init(from decoder: any Decoder) throws {
        conversations = try [ConversationDTO](from: decoder)
    }

    public func toDomain() -> [RemoteConversation] {
        conversations.map { $0.toDomain() }
    }
}
