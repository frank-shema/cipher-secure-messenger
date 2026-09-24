import CipherCore
import Foundation
import SwiftData

/// Device-side message lifecycle: view-once bookkeeping, expiry sweeps, disappearing timers,
/// whole-conversation deletion and the raw envelope bytes behind the Server's-Eye view.
extension PersistenceStore {
    /// Records the first opening of a message. Returns `true` only for that first call, so the
    /// caller can send the `view_once_opened` notice exactly once; the recorded instant never moves,
    /// which is what makes "opened" a fact the UI can rely on even if the app crashed mid-view.
    @discardableResult
    public func markViewed(messageId: MessageID) async throws(PersistenceError) -> Bool {
        guard let row = try messageRow(id: messageId) else {
            throw .messageNotFound(messageId)
        }
        guard row.viewedAt == nil else { return false }
        row.viewedAt = now
        try commit(.messages(ConversationID(row.conversationId)))
        return true
    }

    public func viewedAt(messageId: MessageID) async throws(PersistenceError) -> Date? {
        try messageRow(id: messageId)?.viewedAt
    }

    /// Ids of messages in the conversation that were opened, for rendering view-once placeholders.
    public func viewedMessageIds(conversationId: ConversationID) async throws(PersistenceError) -> Set<MessageID> {
        let conversation = conversationId.uuid
        let rows = try fetch(
            FetchDescriptor<StoredMessage>(predicate: #Predicate { $0.conversationId == conversation && $0.viewedAt != nil })
        )
        return Set(rows.map { MessageID($0.id) })
    }

    /// Deletes every message whose `expiresAt` has passed and returns their ids. Meant to run on
    /// launch, on foreground and on a timer while a chat is open; deleting is the only enforcement
    /// disappearing messages have, since the relay cannot read the flag.
    @discardableResult
    public func deleteExpired(now: Date) async throws(PersistenceError) -> [MessageID] {
        let never = Date.distantFuture
        let rows = try fetch(FetchDescriptor<StoredMessage>(predicate: #Predicate { ($0.expiresAt ?? never) <= now }))
        guard !rows.isEmpty else { return [] }
        let ids = rows.map { MessageID($0.id) }
        try commit(try removeMessages(rows))
        PersistenceLog.store.notice("deleted \(ids.count, privacy: .public) expired messages")
        return ids
    }

    /// Sets (or with `nil` clears) the default disappearing timer for new outgoing messages.
    public func setDisappearingTimer(conversationId: ConversationID, timer: TimeInterval?) async throws(PersistenceError) {
        if let timer, !timer.isFinite || timer <= 0 {
            throw .invalidDisappearingTimer(timer)
        }
        guard try conversationRow(id: conversationId) != nil else {
            throw .conversationNotFound(conversationId)
        }
        try applyDisappearingTimer(timer, conversationId: conversationId, now: now)
        try commit(.conversations)
    }

    /// Removes the conversation, its messages, their queued envelopes and its settings. The send
    /// counter and the seen counters stay: if the same conversation is recreated, the next message
    /// must not reuse a message key and an old envelope must still be rejected as a replay.
    public func deleteConversation(id: ConversationID) async throws(PersistenceError) {
        var changes = try removeMessages(try messageRows(conversationId: id))
        if let settings = try settingsRow(conversationId: id) {
            modelContext.delete(settings)
        }
        if let row = try conversationRow(id: id) {
            modelContext.delete(row)
        }
        changes.append(.messages(id))
        changes.append(.conversations)
        try commit(changes)
        PersistenceLog.store.notice("deleted conversation \(id.description, privacy: .public)")
    }

    /// The exact envelope JSON the relay holds for this message, or `nil` when it was never attached.
    public func rawEnvelope(messageId: MessageID) async throws(PersistenceError) -> Data? {
        try messageRow(id: messageId)?.rawEnvelope
    }

    /// Stores the relay's copy of an incoming envelope next to the decrypted message. Outgoing
    /// envelopes are attached automatically when queued; incoming ones must be attached by the
    /// caller that received them, because the domain `Message` deliberately carries no ciphertext.
    public func attachRawEnvelope(messageId: MessageID, envelope: Envelope) async throws(PersistenceError) {
        try await attachRawEnvelope(messageId: messageId, data: try StoredCodec.encode(envelope))
    }

    public func attachRawEnvelope(messageId: MessageID, data: Data) async throws(PersistenceError) {
        guard let row = try messageRow(id: messageId) else {
            throw .messageNotFound(messageId)
        }
        row.rawEnvelope = data
        try commit([])
    }
}
