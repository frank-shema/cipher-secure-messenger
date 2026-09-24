import CipherCore
import Foundation

// `/api/v1/conversations/*` (PROTOCOL.md §1.3).

/// `POST /conversations` → 201 (created) or 200 (already existed).
public struct CreateConversationEndpoint: Endpoint {
    public typealias Response = ConversationDTO

    public var request: CreateConversationRequest

    public init(participantId: UserID) {
        self.request = CreateConversationRequest(participantId: participantId)
    }

    public var path: String { "conversations" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
}

/// `GET /conversations`.
public struct ListConversationsEndpoint: Endpoint {
    public typealias Response = ConversationListDTO

    public init() {}

    public var path: String { "conversations" }
    public var method: HTTPMethod { .get }
}

/// `POST /conversations/{id}/messages`. The body is Core's `Envelope`: its Codable conformance emits
/// the exact wire keys, and the message id inside it is what makes a retry of the same send idempotent
/// (200 instead of 201).
public struct SendMessageEndpoint: Endpoint {
    public typealias Response = MessageAckDTO

    public var envelope: Envelope

    public init(envelope: Envelope) {
        self.envelope = envelope
    }

    public var path: String { "conversations/\(envelope.conversationId.description)/messages" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(envelope) }
}

/// `GET /conversations/{id}/messages?before=&limit=`.
public struct FetchMessagesEndpoint: Endpoint {
    public typealias Response = MessagePageDTO

    /// Page size bounds the relay enforces; the client clamps rather than letting a 400 surface.
    public static let maxLimit = 200
    public static let defaultLimit = 50

    public var conversationId: ConversationID
    /// Epoch millis; items with `createdAt >= before` are excluded. Nil starts from the newest.
    public var before: Int64?
    public var limit: Int

    public init(conversationId: ConversationID, before: Int64?, limit: Int = FetchMessagesEndpoint.defaultLimit) {
        self.conversationId = conversationId
        self.before = before
        self.limit = min(max(limit, 1), Self.maxLimit)
    }

    public var path: String { "conversations/\(conversationId.description)/messages" }
    public var method: HTTPMethod { .get }

    public var query: [URLQueryItem] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: String(before)))
        }
        return items
    }
}
