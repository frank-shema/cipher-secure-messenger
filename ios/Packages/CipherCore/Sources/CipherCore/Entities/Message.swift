import Foundation

/// A message as the local store holds it: decrypted content plus the envelope metadata the UI needs.
/// `id` and `counter` are client-generated (PROTOCOL.md) so optimistic rows reconcile with acks and
/// retries stay idempotent.
public struct Message: Hashable, Codable, Sendable, Identifiable {
    public var id: MessageID
    public var conversationId: ConversationID
    public var senderId: UserID
    public var recipientId: UserID
    public var direction: MessageDirection
    public var content: MessageContent
    public var flags: MessageFlags
    public var replyToId: MessageID?
    /// Sender's monotonically increasing per-conversation counter; part of the key derivation and AAD.
    public var counter: UInt64
    /// Sender clock at send time (the envelope `timestamp`).
    public var sentAt: Date
    /// Relay clock when the envelope was stored; nil until acknowledged.
    public var serverCreatedAt: Date?
    public var status: MessageStatus
    public var expiresAt: Date?
    public var reactions: [Reaction]

    public init(
        id: MessageID,
        conversationId: ConversationID,
        senderId: UserID,
        recipientId: UserID,
        direction: MessageDirection,
        content: MessageContent,
        flags: MessageFlags,
        replyToId: MessageID?,
        counter: UInt64,
        sentAt: Date,
        serverCreatedAt: Date?,
        status: MessageStatus,
        expiresAt: Date?,
        reactions: [Reaction]
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.direction = direction
        self.content = content
        self.flags = flags
        self.replyToId = replyToId
        self.counter = counter
        self.sentAt = sentAt
        self.serverCreatedAt = serverCreatedAt
        self.status = status
        self.expiresAt = expiresAt
        self.reactions = reactions
    }

    /// The instant used for ordering and "updated at" bookkeeping: the relay clock once known,
    /// otherwise the sender clock.
    public var effectiveTimestamp: Date {
        serverCreatedAt ?? sentAt
    }
}
