import Foundation
import SwiftData

/// One message as the device holds it. Two representations live side by side on purpose:
/// `rawEnvelope` is the exact JSON the relay stores (for the Server's-Eye view, which must show what
/// the server can and cannot see), and `payload` is the decrypted `MessagePayload`. Everything the UI
/// filters or sorts on is denormalised into plain columns so queries never have to decode JSON.
@Model
final class StoredMessage {
    @Attribute(.unique) var id: UUID
    var conversationId: UUID
    var senderId: UUID
    var recipientId: UUID
    /// `MessageDirection` raw value.
    var directionRaw: String
    /// `MessageStatus` raw value.
    var statusRaw: String
    /// Sender's per-conversation counter, stored as the bit pattern of the `UInt64` because SwiftData
    /// persists signed 64-bit integers only. Counters start at 0 and grow by one, so ordering is preserved.
    var counter: Int64
    /// Sender clock (the envelope `timestamp`).
    var sentAt: Date
    /// Relay clock; nil until acknowledged.
    var serverCreatedAt: Date?
    /// When `statusRaw` last advanced, for receipts and tooltips.
    var statusChangedAt: Date?
    /// When both ends delete the message; set from the envelope or scheduled on read for disappearing messages.
    var expiresAt: Date?
    /// Time Capsule: sealed until this instant.
    var unlockAt: Date?
    /// Seconds after read until deletion (`MessageFlags.disappearAfter`).
    var disappearAfter: Double?
    var viewOnce: Bool
    var whisper: Bool
    /// First time a view-once message was opened; never moved once set.
    var viewedAt: Date?
    var replyToId: UUID?
    /// `TamperReason` raw value when the envelope could not be verified or opened; `payload` is nil then.
    var tamperReasonRaw: String?
    /// Encoded `MessagePayload` (plaintext content). Nil for tampered messages.
    var payload: Data?
    /// Encoded `[Reaction]` mirrored onto this message; nil when empty.
    var reactions: Data?
    /// Exact envelope JSON as sent to or received from the relay. External storage keeps the row small
    /// while ciphertext can reach 256 KiB.
    @Attribute(.externalStorage) var rawEnvelope: Data?
    /// Local insertion time, for diagnostics and stable ordering of same-instant rows.
    var storedAt: Date

    init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        recipientId: UUID,
        directionRaw: String,
        statusRaw: String,
        counter: Int64,
        sentAt: Date,
        serverCreatedAt: Date?,
        statusChangedAt: Date?,
        expiresAt: Date?,
        unlockAt: Date?,
        disappearAfter: Double?,
        viewOnce: Bool,
        whisper: Bool,
        viewedAt: Date?,
        replyToId: UUID?,
        tamperReasonRaw: String?,
        payload: Data?,
        reactions: Data?,
        rawEnvelope: Data?,
        storedAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.directionRaw = directionRaw
        self.statusRaw = statusRaw
        self.counter = counter
        self.sentAt = sentAt
        self.serverCreatedAt = serverCreatedAt
        self.statusChangedAt = statusChangedAt
        self.expiresAt = expiresAt
        self.unlockAt = unlockAt
        self.disappearAfter = disappearAfter
        self.viewOnce = viewOnce
        self.whisper = whisper
        self.viewedAt = viewedAt
        self.replyToId = replyToId
        self.tamperReasonRaw = tamperReasonRaw
        self.payload = payload
        self.reactions = reactions
        self.rawEnvelope = rawEnvelope
        self.storedAt = storedAt
    }
}
