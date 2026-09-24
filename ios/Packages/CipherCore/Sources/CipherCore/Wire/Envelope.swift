import Foundation

/// The relay-visible part of a message: the client-generated id plus everything the AEAD
/// authenticates but does not hide. Grouped so sealing, the associated data and the envelope are built
/// from one value and can never disagree about, say, the counter. (`id` is not part of the AAD.)
public struct EnvelopeHeader: Hashable, Codable, Sendable {
    public var id: MessageID
    public var conversationId: ConversationID
    public var senderId: UserID
    public var recipientId: UserID
    public var counter: UInt64
    public var timestampMillis: Int64
    /// Only content-related field the relay may see, so it can purge disappearing messages.
    public var expiresAtMillis: Int64?

    public init(
        id: MessageID,
        conversationId: ConversationID,
        senderId: UserID,
        recipientId: UserID,
        counter: UInt64,
        timestampMillis: Int64,
        expiresAtMillis: Int64?
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.counter = counter
        self.timestampMillis = timestampMillis
        self.expiresAtMillis = expiresAtMillis
    }
}

/// The wire envelope (PROTOCOL.md §1.3): opaque ciphertext plus routing metadata. Timestamps stay as
/// epoch milliseconds here because `timestamp` is part of the AAD and must round-trip byte-for-byte.
public struct Envelope: Hashable, Sendable {
    public var version: Int
    public var id: MessageID
    public var conversationId: ConversationID
    public var senderId: UserID
    public var recipientId: UserID
    public var counter: UInt64
    public var timestamp: Int64
    public var ciphertext: Data
    public var signature: Data
    public var expiresAt: Int64?

    public init(
        version: Int = CipherCore.protocolVersion,
        id: MessageID,
        conversationId: ConversationID,
        senderId: UserID,
        recipientId: UserID,
        counter: UInt64,
        timestamp: Int64,
        ciphertext: Data,
        signature: Data,
        expiresAt: Int64?
    ) {
        self.version = version
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.counter = counter
        self.timestamp = timestamp
        self.ciphertext = ciphertext
        self.signature = signature
        self.expiresAt = expiresAt
    }

    public init(header: EnvelopeHeader, ciphertext: Data, signature: Data, version: Int = CipherCore.protocolVersion) {
        self.init(
            version: version,
            id: header.id,
            conversationId: header.conversationId,
            senderId: header.senderId,
            recipientId: header.recipientId,
            counter: header.counter,
            timestamp: header.timestampMillis,
            ciphertext: ciphertext,
            signature: signature,
            expiresAt: header.expiresAtMillis
        )
    }

    public var header: EnvelopeHeader {
        EnvelopeHeader(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            recipientId: recipientId,
            counter: counter,
            timestampMillis: timestamp,
            expiresAtMillis: expiresAt
        )
    }

    public var sentAt: Date {
        Date(epochMillis: timestamp)
    }

    public var expiresAtDate: Date? {
        expiresAt.map { Date(epochMillis: $0) }
    }
}

extension Envelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case id
        case conversationId
        case senderId
        case recipientId
        case counter
        case timestamp
        case ciphertext
        case signature
        case expiresAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        id = try container.decode(MessageID.self, forKey: .id)
        conversationId = try container.decode(ConversationID.self, forKey: .conversationId)
        senderId = try container.decode(UserID.self, forKey: .senderId)
        recipientId = try container.decode(UserID.self, forKey: .recipientId)
        counter = try container.decode(UInt64.self, forKey: .counter)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        ciphertext = try container.decodeBase64(forKey: .ciphertext)
        signature = try container.decodeBase64(forKey: .signature)
        expiresAt = try container.decodeIfPresent(Int64.self, forKey: .expiresAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(recipientId, forKey: .recipientId)
        try container.encode(counter, forKey: .counter)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeBase64(ciphertext, forKey: .ciphertext)
        try container.encodeBase64(signature, forKey: .signature)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}
