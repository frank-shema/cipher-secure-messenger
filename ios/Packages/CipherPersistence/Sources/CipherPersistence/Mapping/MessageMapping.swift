import CipherCore
import Foundation

/// Translates between the domain `Message` and its row. Content is stored as the encoded
/// `MessagePayload` it was built from, so a retry can re-seal exactly the same bytes, while the
/// flags are copied into their own columns for querying (expiry sweeps, capsule unlocks).
enum MessageMapping {
    static func makeRow(from message: Message, now: Date) throws(PersistenceError) -> StoredMessage {
        let blobs = try Blobs(message)
        let row = StoredMessage(
            id: message.id.uuid,
            conversationId: message.conversationId.uuid,
            senderId: message.senderId.uuid,
            recipientId: message.recipientId.uuid,
            directionRaw: message.direction.rawValue,
            statusRaw: message.status.rawValue,
            counter: Int64(bitPattern: message.counter),
            sentAt: message.sentAt,
            serverCreatedAt: message.serverCreatedAt,
            statusChangedAt: now,
            expiresAt: message.expiresAt,
            unlockAt: message.flags.unlockAt,
            disappearAfter: message.flags.disappearAfter,
            viewOnce: message.flags.viewOnce,
            whisper: message.flags.whisper,
            viewedAt: nil,
            replyToId: message.replyToId?.uuid,
            tamperReasonRaw: message.content.tamperReason?.rawValue,
            payload: blobs.payload,
            reactions: blobs.reactions,
            rawEnvelope: nil,
            storedAt: now
        )
        if message.status == .read {
            scheduleDisappearance(of: row, readAt: now)
        }
        return row
    }

    /// Overwrites the domain-owned columns and leaves the device-owned ones (`rawEnvelope`,
    /// `viewedAt`, `storedAt`) alone: a use case re-upserting a message must never erase what only
    /// this device knows about it.
    static func apply(_ message: Message, to row: StoredMessage, now: Date) throws(PersistenceError) {
        let blobs = try Blobs(message)
        if row.statusRaw != message.status.rawValue {
            row.statusChangedAt = now
        }
        row.conversationId = message.conversationId.uuid
        row.senderId = message.senderId.uuid
        row.recipientId = message.recipientId.uuid
        row.directionRaw = message.direction.rawValue
        row.statusRaw = message.status.rawValue
        row.counter = Int64(bitPattern: message.counter)
        row.sentAt = message.sentAt
        row.serverCreatedAt = message.serverCreatedAt ?? row.serverCreatedAt
        row.expiresAt = message.expiresAt ?? row.expiresAt
        row.unlockAt = message.flags.unlockAt
        row.disappearAfter = message.flags.disappearAfter
        row.viewOnce = message.flags.viewOnce
        row.whisper = message.flags.whisper
        row.replyToId = message.replyToId?.uuid
        row.tamperReasonRaw = message.content.tamperReason?.rawValue
        row.payload = blobs.payload
        row.reactions = blobs.reactions
        if message.status == .read {
            scheduleDisappearance(of: row, readAt: now)
        }
    }

    static func message(from row: StoredMessage) -> Message {
        Message(
            id: MessageID(row.id),
            conversationId: ConversationID(row.conversationId),
            senderId: UserID(row.senderId),
            recipientId: UserID(row.recipientId),
            direction: MessageDirection(rawValue: row.directionRaw) ?? .incoming,
            content: content(of: row),
            flags: MessageFlags(
                viewOnce: row.viewOnce,
                whisper: row.whisper,
                disappearAfter: row.disappearAfter,
                unlockAt: row.unlockAt
            ),
            replyToId: row.replyToId.map(MessageID.init),
            counter: UInt64(bitPattern: row.counter),
            sentAt: row.sentAt,
            serverCreatedAt: row.serverCreatedAt,
            status: MessageStatus(rawValue: row.statusRaw) ?? .sent,
            expiresAt: row.expiresAt,
            reactions: row.reactions.flatMap { StoredCodec.decode([Reaction].self, from: $0) } ?? []
        )
    }

    /// Starts the disappearing countdown the first time a message is known to have been read. The
    /// deadline is never moved once set, so re-reading or a duplicate receipt cannot extend it.
    static func scheduleDisappearance(of row: StoredMessage, readAt: Date) {
        guard row.expiresAt == nil, let seconds = row.disappearAfter, seconds > 0 else { return }
        row.expiresAt = readAt.addingTimeInterval(seconds)
    }

    /// A row without a readable payload is shown as tampered rather than dropped: the person should
    /// see that something arrived and could not be trusted.
    private static func content(of row: StoredMessage) -> MessageContent {
        if let data = row.payload, let payload = StoredCodec.decode(MessagePayload.self, from: data) {
            return payload.content
        }
        if let raw = row.tamperReasonRaw, let reason = TamperReason(rawValue: raw) {
            return .tampered(reason)
        }
        return .tampered(.malformedPayload)
    }

    private struct Blobs {
        let payload: Data?
        let reactions: Data?

        init(_ message: Message) throws(PersistenceError) {
            if let payload = MessagePayload(content: message.content, flags: message.flags, replyToId: message.replyToId) {
                self.payload = try StoredCodec.encode(payload)
            } else {
                self.payload = nil
            }
            reactions = message.reactions.isEmpty ? nil : try StoredCodec.encode(message.reactions)
        }
    }
}
