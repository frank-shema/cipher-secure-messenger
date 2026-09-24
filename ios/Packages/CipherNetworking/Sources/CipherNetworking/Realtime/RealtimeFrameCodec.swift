import CipherCore
import Foundation

/// Translates between JSON frames `{ "v", "type", "payload" }` (PROTOCOL.md §2) and Core's typed
/// events. Inbound frames are decoded in two passes: the header first, then the payload with the type
/// the header names, so one decoder handles every event without a hand-written JSON walker.
public enum RealtimeFrameCodec {
    public static func encode(_ event: ClientEvent) throws(RealtimeFrameError) -> String {
        do {
            let data: Data
            switch event {
            case let .messageAck(messageIds):
                data = try WireJSON.encode(OutboundFrame(type: event.type, payload: MessageAckPayload(messageIds: messageIds)))
            case let .receiptRead(conversationId, messageIds):
                let payload = ReceiptReadPayload(conversationId: conversationId, messageIds: messageIds)
                data = try WireJSON.encode(OutboundFrame(type: event.type, payload: payload))
            case let .typingStart(conversationId), let .typingStop(conversationId):
                data = try WireJSON.encode(OutboundFrame(type: event.type, payload: TypingRequestPayload(conversationId: conversationId)))
            case .ping:
                data = try WireJSON.encode(OutboundFrame(type: event.type, payload: EmptyPayload()))
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw RealtimeFrameError.malformed("frame is not UTF-8")
            }
            return text
        } catch let error as RealtimeFrameError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }

    public static func decode(_ text: String) throws(RealtimeFrameError) -> ServerEvent {
        try decode(Data(text.utf8))
    }

    public static func decode(_ data: Data) throws(RealtimeFrameError) -> ServerEvent {
        let header: InboundHeader
        do {
            header = try WireJSON.decode(InboundHeader.self, from: data)
        } catch {
            throw .malformed(String(describing: error))
        }
        guard header.version == CipherCore.protocolVersion else {
            throw .unsupportedVersion(header.version)
        }
        guard let type = ServerEventType(rawValue: header.type) else {
            throw .unknownType(header.type)
        }
        do {
            return try decodePayload(of: type, from: data)
        } catch {
            throw .malformed(String(describing: error))
        }
    }

    private static func decodePayload(of type: ServerEventType, from data: Data) throws -> ServerEvent {
        switch type {
        case .messageNew:
            return .messageNew(try payload(StoredEnvelope.self, from: data))
        case .receiptDelivered:
            return .receiptDelivered(try payload(ReceiptPayload.self, from: data).toDomain())
        case .receiptRead:
            return .receiptRead(try payload(ReceiptPayload.self, from: data).toDomain())
        case .typingStart:
            let typing = try payload(TypingEventPayload.self, from: data)
            return .typingStart(conversationId: typing.conversationId, userId: typing.userId)
        case .typingStop:
            let typing = try payload(TypingEventPayload.self, from: data)
            return .typingStop(conversationId: typing.conversationId, userId: typing.userId)
        case .presenceUpdate:
            let presence = try payload(PresencePayload.self, from: data)
            return .presenceUpdate(userId: presence.userId, presence: presence.toDomain())
        case .keyChanged:
            return .keyChanged(try payload(KeyChangedPayload.self, from: data).toDomain())
        case .error:
            let error = try payload(ErrorPayload.self, from: data)
            return .error(code: error.code, message: error.message, correlationId: error.correlationId)
        case .pong:
            return .pong
        }
    }

    private static func payload<P: Decodable>(_ type: P.Type, from data: Data) throws -> P {
        try WireJSON.decode(InboundFrame<P>.self, from: data).payload
    }
}

// MARK: - Frame shapes

private struct InboundHeader: Decodable {
    var version: Int
    var type: String

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case type
    }
}

private struct InboundFrame<Payload: Decodable>: Decodable {
    var payload: Payload
}

private struct OutboundFrame<Payload: Encodable>: Encodable {
    var version = CipherCore.protocolVersion
    var type: String
    var payload: Payload

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case type
        case payload
    }

    init(type: ClientEventType, payload: Payload) {
        self.type = type.rawValue
        self.payload = payload
    }
}

// MARK: - Client → server payloads (PROTOCOL.md §2.2)

private struct EmptyPayload: Encodable {}

private struct MessageAckPayload: Encodable {
    var messageIds: [MessageID]
}

private struct ReceiptReadPayload: Encodable {
    var conversationId: ConversationID
    var messageIds: [MessageID]
}

private struct TypingRequestPayload: Encodable {
    var conversationId: ConversationID
}

// MARK: - Server → client payloads (PROTOCOL.md §2.1)

private struct ReceiptPayload: Decodable {
    var conversationId: ConversationID
    var messageIds: [MessageID]
    var byUserId: UserID
    var at: Int64

    func toDomain() -> Receipt {
        Receipt(conversationId: conversationId, messageIds: messageIds, byUserId: byUserId, at: Date(epochMillis: at))
    }
}

private struct TypingEventPayload: Decodable {
    var conversationId: ConversationID
    var userId: UserID
}

private struct PresencePayload: Decodable {
    var userId: UserID
    var online: Bool
    var lastSeenAt: Int64?

    func toDomain() -> Presence {
        Presence(online: online, lastSeenAt: lastSeenAt.map { Date(epochMillis: $0) })
    }
}

private struct KeyChangedPayload: Decodable {
    var userId: UserID
    var version: Int
    var identityKey: Base64Data
    var signingKey: Base64Data
    var changedAt: Int64

    func toDomain() -> PublicKeyBundle {
        PublicKeyBundle(
            userId: userId,
            identityKey: identityKey.data,
            signingKey: signingKey.data,
            version: version,
            createdAt: Date(epochMillis: changedAt)
        )
    }
}

private struct ErrorPayload: Decodable {
    var code: String
    var message: String
    var correlationId: String?
}
