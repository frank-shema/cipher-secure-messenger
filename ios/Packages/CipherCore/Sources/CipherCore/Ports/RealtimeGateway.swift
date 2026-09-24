import Foundation

/// A delivery or read receipt relayed from the other participant.
public struct Receipt: Hashable, Sendable {
    public var conversationId: ConversationID
    public var messageIds: [MessageID]
    public var byUserId: UserID
    public var at: Date

    public init(conversationId: ConversationID, messageIds: [MessageID], byUserId: UserID, at: Date) {
        self.conversationId = conversationId
        self.messageIds = messageIds
        self.byUserId = byUserId
        self.at = at
    }
}

/// Frame `type` strings for server → client events (PROTOCOL.md §2.1), the single source of truth
/// for the frame codec.
public enum ServerEventType: String, Hashable, Sendable, CaseIterable {
    case messageNew = "message.new"
    case receiptDelivered = "receipt.delivered"
    case receiptRead = "receipt.read"
    case typingStart = "typing.start"
    case typingStop = "typing.stop"
    case presenceUpdate = "presence.update"
    case keyChanged = "key.changed"
    case error
    case pong
}

/// Server → client events (PROTOCOL.md §2.1).
public enum ServerEvent: Hashable, Sendable {
    case messageNew(StoredEnvelope)
    case receiptDelivered(Receipt)
    case receiptRead(Receipt)
    case typingStart(conversationId: ConversationID, userId: UserID)
    case typingStop(conversationId: ConversationID, userId: UserID)
    case presenceUpdate(userId: UserID, presence: Presence)
    /// `createdAt` of the bundle is the event's `changedAt`.
    case keyChanged(PublicKeyBundle)
    case error(code: String, message: String, correlationId: String?)
    case pong

    public var type: ServerEventType {
        switch self {
        case .messageNew: .messageNew
        case .receiptDelivered: .receiptDelivered
        case .receiptRead: .receiptRead
        case .typingStart: .typingStart
        case .typingStop: .typingStop
        case .presenceUpdate: .presenceUpdate
        case .keyChanged: .keyChanged
        case .error: .error
        case .pong: .pong
        }
    }
}

/// Frame `type` strings for client → server events (PROTOCOL.md §2.2).
public enum ClientEventType: String, Hashable, Sendable, CaseIterable {
    case messageAck = "message.ack"
    case receiptRead = "receipt.read"
    case typingStart = "typing.start"
    case typingStop = "typing.stop"
    case ping
}

/// Client → server events (PROTOCOL.md §2.2).
public enum ClientEvent: Hashable, Sendable {
    /// Confirms a push was received; unacked envelopes are re-pushed on the next connect.
    case messageAck(messageIds: [MessageID])
    case receiptRead(conversationId: ConversationID, messageIds: [MessageID])
    case typingStart(conversationId: ConversationID)
    case typingStop(conversationId: ConversationID)
    case ping

    public var type: ClientEventType {
        switch self {
        case .messageAck: .messageAck
        case .receiptRead: .receiptRead
        case .typingStart: .typingStart
        case .typingStop: .typingStop
        case .ping: .ping
        }
    }
}

public enum ConnectionState: Hashable, Sendable {
    case connecting
    case connected
    /// Disconnected with a scheduled reconnect, or none when reconnecting was given up.
    case disconnected(retryIn: TimeInterval?)
    /// The device has no network at all; reconnect attempts are paused.
    case offline
}

/// The `/ws` connection (PROTOCOL.md §2). Both streams are `async` getters so an actor-based client
/// can serve them from isolated state; a fresh stream is returned per access and each stream has one
/// consumer.
public protocol RealtimeGateway: Sendable {
    var events: AsyncStream<ServerEvent> { get async }
    var connectionState: AsyncStream<ConnectionState> { get async }
    func connect() async
    func disconnect() async
    func send(_ event: ClientEvent) async throws
}
