import CipherCore
import Foundation
import SwiftData

extension PersistenceStore: MessageRepository {
    public func upsert(_ message: Message) async throws(PersistenceError) {
        let now = now
        if let row = try messageRow(id: message.id) {
            try MessageMapping.apply(message, to: row, now: now)
        } else {
            let row = try MessageMapping.makeRow(from: message, now: now)
            modelContext.insert(row)
        }
        try commit(.messages(message.conversationId))
    }

    public func fetch(id: MessageID) async throws(PersistenceError) -> Message? {
        try messageRow(id: id).map(MessageMapping.message(from:))
    }

    public func fetch(conversationId: ConversationID, senderId: UserID, counter: UInt64) async throws(PersistenceError) -> Message? {
        let conversation = conversationId.uuid
        let sender = senderId.uuid
        let counterValue = Int64(bitPattern: counter)
        let row = try fetchFirst(
            #Predicate<StoredMessage> { $0.conversationId == conversation && $0.senderId == sender && $0.counter == counterValue }
        )
        return row.map(MessageMapping.message(from:))
    }

    /// Pages backwards from `before` (sender clock) and returns the page oldest-first, the order the
    /// chat renders it in. `storedAt` breaks ties so two messages sent in the same millisecond keep a
    /// stable order across refetches.
    public func fetch(conversationId: ConversationID, limit: Int, before: Date?) async throws(PersistenceError) -> [Message] {
        guard limit > 0 else { return [] }
        let conversation = conversationId.uuid
        let predicate: Predicate<StoredMessage>
        if let before {
            predicate = #Predicate { $0.conversationId == conversation && $0.sentAt < before }
        } else {
            predicate = #Predicate { $0.conversationId == conversation }
        }
        var descriptor = FetchDescriptor<StoredMessage>(predicate: predicate, sortBy: Self.newestFirst)
        descriptor.fetchLimit = limit
        return try fetch(descriptor).reversed().map(MessageMapping.message(from:))
    }

    public func knownIds(among ids: [MessageID]) async throws(PersistenceError) -> Set<MessageID> {
        Set(try messageRows(ids: ids).map { MessageID($0.id) })
    }

    public func updateStatus(ids: [MessageID], status: MessageStatus, at: Date) async throws(PersistenceError) {
        var touched = Set<ConversationID>()
        for row in try messageRows(ids: ids) where advance(row, to: status, at: at) {
            touched.insert(ConversationID(row.conversationId))
        }
        try commit(touched.map(PersistenceChange.messages))
    }

    /// The reserved counter is the larger of the persisted "next" value and one past the highest
    /// outgoing counter already stored. The second source matters after a reinstall: history sync
    /// restores old outgoing messages before any counter row exists, and handing out a counter the
    /// peer has already seen would make them reject the message as a replay.
    public func nextCounter(conversationId: ConversationID) async throws(PersistenceError) -> UInt64 {
        let conversation = conversationId.uuid
        let now = now
        let row: StoredSendCounter
        if let existing = try fetchFirst(#Predicate<StoredSendCounter> { $0.conversationId == conversation }) {
            row = existing
        } else {
            row = StoredSendCounter(conversationId: conversation, nextCounter: 0, updatedAt: now)
            modelContext.insert(row)
        }
        let reserved = max(row.nextCounter, try highestOutgoingCounter(conversationId: conversation) + 1)
        row.nextCounter = reserved + 1
        row.updatedAt = now
        try commit([])
        return UInt64(bitPattern: reserved)
    }

    /// Time Capsules are left alone until they unlock: the person has not read what they cannot open,
    /// so neither the read receipt nor a disappearing countdown should start.
    public func markRead(conversationId: ConversationID, at: Date) async throws(PersistenceError) -> [MessageID] {
        let conversation = conversationId.uuid
        let incoming = MessageDirection.incoming.rawValue
        let read = MessageStatus.read.rawValue
        let rows = try fetch(
            FetchDescriptor<StoredMessage>(
                predicate: #Predicate { $0.conversationId == conversation && $0.directionRaw == incoming && $0.statusRaw != read }
            )
        )
        var changed: [MessageID] = []
        for row in rows where (row.unlockAt ?? .distantPast) <= at && advance(row, to: .read, at: at) {
            changed.append(MessageID(row.id))
        }
        guard !changed.isEmpty else { return [] }
        try commit(.messages(conversationId))
        PersistenceLog.store.debug("marked \(changed.count, privacy: .public) read in \(conversationId.description, privacy: .public)")
        return changed
    }

    public func delete(ids: [MessageID]) async throws(PersistenceError) {
        let rows = try messageRows(ids: ids)
        guard !rows.isEmpty else { return }
        try commit(try removeMessages(rows))
    }
}

// MARK: - Shared message helpers

extension PersistenceStore {
    static let newestFirst = [
        SortDescriptor(\StoredMessage.sentAt, order: .reverse),
        SortDescriptor(\StoredMessage.storedAt, order: .reverse)
    ]

    static let oldestFirst = [
        SortDescriptor(\StoredMessage.sentAt, order: .forward),
        SortDescriptor(\StoredMessage.storedAt, order: .forward)
    ]

    /// Applies `status` through `MessageStatus.shouldAdvance(to:)` and reports whether the row changed.
    private func advance(_ row: StoredMessage, to status: MessageStatus, at date: Date) -> Bool {
        guard let current = MessageStatus(rawValue: row.statusRaw), current != status, current.shouldAdvance(to: status) else {
            return false
        }
        row.statusRaw = status.rawValue
        row.statusChangedAt = date
        if status == .read {
            MessageMapping.scheduleDisappearance(of: row, readAt: date)
        }
        return true
    }

    private func highestOutgoingCounter(conversationId: UUID) throws(PersistenceError) -> Int64 {
        let outgoing = MessageDirection.outgoing.rawValue
        var descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.conversationId == conversationId && $0.directionRaw == outgoing },
            sortBy: [SortDescriptor(\.counter, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first?.counter ?? -1
    }

    /// Deletes message rows together with their queued envelopes and repairs any conversation whose
    /// `lastMessageId` pointed at one of them. Send and seen counters are deliberately left behind: a
    /// deleted message must not free its counter for reuse, nor let its envelope be accepted again.
    func removeMessages(_ rows: [StoredMessage]) throws(PersistenceError) -> [PersistenceChange] {
        let ids = rows.map(\.id)
        let conversations = Set(rows.map(\.conversationId))
        for item in try outboxRows(messageIds: ids) {
            modelContext.delete(item)
        }
        for row in rows {
            modelContext.delete(row)
        }
        for conversationId in conversations {
            guard let conversation = try conversationRow(id: ConversationID(conversationId)),
                  let last = conversation.lastMessageId, ids.contains(last) else { continue }
            conversation.lastMessageId = try newestMessageRow(conversationId: conversationId)?.id
        }
        return conversations.map { PersistenceChange.messages(ConversationID($0)) } + [.conversations]
    }

    private func newestMessageRow(conversationId: UUID) throws(PersistenceError) -> StoredMessage? {
        var descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: Self.newestFirst
        )
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    func messagesSnapshot(conversationId: ConversationID) throws(PersistenceError) -> [Message] {
        let conversation = conversationId.uuid
        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.conversationId == conversation },
            sortBy: Self.oldestFirst
        )
        return try fetch(descriptor).map(MessageMapping.message(from:))
    }
}
