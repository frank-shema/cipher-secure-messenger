import CipherCore
import Foundation
import SwiftData

extension PersistenceStore: OutboxRepository {
    /// Idempotent by message id: a retry that re-seals replaces the queued bytes but keeps its place
    /// in the queue and its attempt history. The same bytes are mirrored onto the message row so the
    /// Server's-Eye view can show an outgoing envelope without a second call from the send path.
    public func enqueue(_ item: OutboxItem) async throws(PersistenceError) {
        let data = try StoredCodec.encode(item.envelope)
        if let row = try outboxRow(messageId: item.messageId) {
            row.envelope = data
        } else {
            let row = StoredOutboxItem(
                messageId: item.messageId.uuid,
                envelope: data,
                enqueuedAt: item.enqueuedAt,
                attempts: item.attempts,
                lastError: item.lastError,
                lastAttemptAt: nil
            )
            modelContext.insert(row)
        }
        if let message = try messageRow(id: item.messageId) {
            message.rawEnvelope = data
        }
        try commit([])
    }

    public func item(messageId: MessageID) async throws(PersistenceError) -> OutboxItem? {
        guard let row = try outboxRow(messageId: messageId) else { return nil }
        return try decode(row)
    }

    public func pending() async throws(PersistenceError) -> [OutboxItem] {
        let rows = try fetch(FetchDescriptor<StoredOutboxItem>(sortBy: [SortDescriptor(\.enqueuedAt, order: .forward)]))
        var items: [OutboxItem] = []
        items.reserveCapacity(rows.count)
        for row in rows {
            if let item = try decode(row) {
                items.append(item)
            }
        }
        try commit([])
        return items
    }

    public func remove(messageId: MessageID) async throws(PersistenceError) {
        guard let row = try outboxRow(messageId: messageId) else { return }
        modelContext.delete(row)
        try commit([])
    }

    public func markAttempt(messageId: MessageID, error: String?, at: Date) async throws(PersistenceError) {
        guard let row = try outboxRow(messageId: messageId) else { return }
        row.attempts += 1
        row.lastError = error
        row.lastAttemptAt = at
        try commit([])
    }

    /// A queued envelope that no longer decodes can never be sent, so the row is dropped on sight;
    /// the message keeps its `sending`/`failed` status and a retry re-seals it from the payload.
    private func decode(_ row: StoredOutboxItem) throws(PersistenceError) -> OutboxItem? {
        guard let envelope = StoredCodec.decode(Envelope.self, from: row.envelope) else {
            PersistenceLog.store.error("dropping unreadable outbox row \(row.messageId, privacy: .public)")
            modelContext.delete(row)
            return nil
        }
        return OutboxItem(
            messageId: MessageID(row.messageId),
            envelope: envelope,
            enqueuedAt: row.enqueuedAt,
            attempts: row.attempts,
            lastError: row.lastError
        )
    }
}
