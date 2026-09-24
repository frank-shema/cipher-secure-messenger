import CipherCore
import Foundation
import SwiftData

extension PersistenceStore: ConversationRepository {
    /// Writes the embedded contact through to the contacts table. Use cases always pin keys right
    /// before upserting a conversation, so the embedded value is the freshest one and keeping the two
    /// tables in step here is what lets `fetch` rebuild the same conversation later.
    public func upsert(_ conversation: Conversation) async throws(PersistenceError) {
        let now = now
        try upsertContactRow(conversation.contact, now: now)
        if let row = try conversationRow(id: conversation.id) {
            row.contactId = conversation.contact.id.uuid
            row.lastMessageId = conversation.lastMessage?.id.uuid ?? row.lastMessageId
            row.unreadCount = max(0, conversation.unreadCount)
            row.updatedAt = conversation.updatedAt
        } else {
            let row = StoredConversation(
                id: conversation.id.uuid,
                contactId: conversation.contact.id.uuid,
                lastMessageId: conversation.lastMessage?.id.uuid,
                unreadCount: max(0, conversation.unreadCount),
                updatedAt: conversation.updatedAt,
                createdAt: now
            )
            modelContext.insert(row)
        }
        try applyDisappearingTimer(
            ConversationMapping.normalizedTimer(conversation.disappearingTimer),
            conversationId: conversation.id,
            now: now
        )
        try commit([.conversations, .contact(conversation.contact.id)])
    }

    public func fetch(id: ConversationID) async throws(PersistenceError) -> Conversation? {
        guard let row = try conversationRow(id: id) else { return nil }
        return try assemble(row)
    }

    public func fetchAll() async throws(PersistenceError) -> [Conversation] {
        try conversationsSnapshot()
    }

    public func updateLastMessage(conversationId: ConversationID, message: Message) async throws(PersistenceError) {
        guard let row = try conversationRow(id: conversationId) else {
            throw .conversationNotFound(conversationId)
        }
        row.lastMessageId = message.id.uuid
        row.updatedAt = max(row.updatedAt, message.effectiveTimestamp)
        try commit(.conversations)
    }

    public func setUnread(conversationId: ConversationID, count: Int) async throws(PersistenceError) {
        guard let row = try conversationRow(id: conversationId) else {
            throw .conversationNotFound(conversationId)
        }
        row.unreadCount = max(0, count)
        try commit(.conversations)
    }

    public func delete(id: ConversationID) async throws(PersistenceError) {
        try await deleteConversation(id: id)
    }
}

// MARK: - Assembly

extension PersistenceStore {
    func applyDisappearingTimer(_ timer: TimeInterval?, conversationId: ConversationID, now: Date) throws(PersistenceError) {
        if let settings = try settingsRow(conversationId: conversationId) {
            guard settings.disappearingTimer != timer else { return }
            settings.disappearingTimer = timer
            settings.updatedAt = now
        } else if timer != nil {
            modelContext.insert(StoredConversationSettings(conversationId: conversationId.uuid, disappearingTimer: timer, updatedAt: now))
        }
    }

    private func assemble(_ row: StoredConversation) throws(PersistenceError) -> Conversation? {
        guard let contact = try contactRow(userId: UserID(row.contactId)) else {
            PersistenceLog.store.error("conversation \(row.id, privacy: .public) has no contact row")
            return nil
        }
        var lastMessage: Message?
        if let lastId = row.lastMessageId, let messageRow = try messageRow(id: MessageID(lastId)) {
            lastMessage = MessageMapping.message(from: messageRow)
        }
        return ConversationMapping.conversation(
            from: row,
            contact: ContactMapping.contact(from: contact),
            lastMessage: lastMessage,
            settings: try settingsRow(conversationId: ConversationID(row.id))
        )
    }

    /// The inbox list, newest activity first. Everything is fetched in four queries rather than four
    /// per row because this runs again after every mutation while the list is on screen.
    func conversationsSnapshot() throws(PersistenceError) -> [Conversation] {
        let rows = try fetch(FetchDescriptor<StoredConversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        guard !rows.isEmpty else { return [] }
        let contactIds = rows.map(\.contactId)
        let contacts = Dictionary(
            try fetch(FetchDescriptor<StoredContact>(predicate: #Predicate { contactIds.contains($0.userId) })).map { ($0.userId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let messageIds = rows.compactMap(\.lastMessageId)
        let messages = Dictionary(
            try messageRows(ids: messageIds.map(MessageID.init)).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let conversationIds = rows.map(\.id)
        let settings = Dictionary(
            try fetch(FetchDescriptor<StoredConversationSettings>(predicate: #Predicate { conversationIds.contains($0.conversationId) }))
                .map { ($0.conversationId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return rows.compactMap { row in
            guard let contact = contacts[row.contactId] else {
                PersistenceLog.store.error("conversation \(row.id, privacy: .public) has no contact row")
                return nil
            }
            return ConversationMapping.conversation(
                from: row,
                contact: ContactMapping.contact(from: contact),
                lastMessage: row.lastMessageId.flatMap { messages[$0] }.map(MessageMapping.message(from:)),
                settings: settings[row.id]
            )
        }
    }
}
