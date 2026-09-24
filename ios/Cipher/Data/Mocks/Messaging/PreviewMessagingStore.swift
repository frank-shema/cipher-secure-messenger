import CipherCore
import Foundation

/// In-memory stand-in for the persistence layer: implements the three repositories the messaging
/// ViewModels observe and re-emits full snapshots after every mutation, exactly like the SwiftData
/// store's change notifier does. Seeded with `MessagingFixtures` for previews.
actor PreviewMessagingStore: MessageRepository, ConversationRepository, ContactRepository {
    private var messages: [MessageID: Message] = [:]
    private var conversations: [ConversationID: Conversation] = [:]
    private var contacts: [UserID: Contact] = [:]
    private var counters: [ConversationID: UInt64] = [:]
    private var messageObservers: [UUID: (ConversationID, AsyncStream<[Message]>.Continuation)] = [:]
    private var conversationObservers: [UUID: AsyncStream<[Conversation]>.Continuation] = [:]
    private var contactObservers: [UUID: (UserID, AsyncStream<Contact>.Continuation)] = [:]

    init(conversations: [Conversation] = [], contacts: [Contact] = [], messages: [Message] = []) {
        for conversation in conversations { self.conversations[conversation.id] = conversation }
        for contact in contacts { self.contacts[contact.id] = contact }
        for message in messages {
            self.messages[message.id] = message
            if message.direction == .outgoing {
                counters[message.conversationId] = max(counters[message.conversationId] ?? 0, message.counter)
            }
        }
    }

    /// Seeded with the full fixture set, frozen at `now`.
    static func seeded(now: Date = Date()) -> PreviewMessagingStore {
        PreviewMessagingStore(
            conversations: MessagingFixtures.conversations(now: now),
            contacts: MessagingFixtures.contacts(now: now),
            messages: MessagingFixtures.bobThread(now: now)
        )
    }

    // MARK: MessageRepository

    func upsert(_ message: Message) async throws {
        messages[message.id] = message
        emitMessages(for: message.conversationId)
    }

    func fetch(id: MessageID) async throws -> Message? {
        messages[id]
    }

    func fetch(conversationId: ConversationID, senderId: UserID, counter: UInt64) async throws -> Message? {
        messages.values.first { $0.conversationId == conversationId && $0.senderId == senderId && $0.counter == counter }
    }

    func fetch(conversationId: ConversationID, limit: Int, before: Date?) async throws -> [Message] {
        sorted(in: conversationId)
            .filter { message in
                guard let before else { return true }
                return message.effectiveTimestamp < before
            }
            .suffix(limit)
            .map { $0 }
    }

    func knownIds(among ids: [MessageID]) async throws -> Set<MessageID> {
        Set(ids.filter { messages[$0] != nil })
    }

    func observe(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<[Message]>.makeStream()
        messageObservers[key] = (conversationId, continuation)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeMessageObserver(key) }
        }
        continuation.yield(sorted(in: conversationId))
        return stream
    }

    func updateStatus(ids: [MessageID], status: MessageStatus, at: Date) async throws {
        var touched: Set<ConversationID> = []
        for id in ids {
            guard var message = messages[id], message.status.shouldAdvance(to: status) else { continue }
            message.status = status
            messages[id] = message
            touched.insert(message.conversationId)
        }
        touched.forEach(emitMessages)
    }

    func nextCounter(conversationId: ConversationID) async throws -> UInt64 {
        let next = (counters[conversationId] ?? 0) + 1
        counters[conversationId] = next
        return next
    }

    func markRead(conversationId: ConversationID, at: Date) async throws -> [MessageID] {
        let unread = sorted(in: conversationId).filter { $0.direction == .incoming && $0.status != .read }.map(\.id)
        try await updateStatus(ids: unread, status: .read, at: at)
        if var conversation = conversations[conversationId], !unread.isEmpty {
            conversation.unreadCount = 0
            conversations[conversationId] = conversation
            emitConversations()
        }
        return unread
    }

    func delete(ids: [MessageID]) async throws {
        var touched: Set<ConversationID> = []
        for id in ids {
            if let removed = messages.removeValue(forKey: id) { touched.insert(removed.conversationId) }
        }
        touched.forEach(emitMessages)
    }

    // MARK: ConversationRepository

    func upsert(_ conversation: Conversation) async throws {
        conversations[conversation.id] = conversation
        contacts[conversation.contact.id] = conversation.contact
        emitConversations()
    }

    func fetch(id: ConversationID) async throws -> Conversation? {
        conversations[id]
    }

    func fetchAll() async throws -> [Conversation] {
        conversations.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func observeAll() async -> AsyncStream<[Conversation]> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<[Conversation]>.makeStream()
        conversationObservers[key] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeConversationObserver(key) }
        }
        continuation.yield(conversations.values.sorted { $0.updatedAt > $1.updatedAt })
        return stream
    }

    func updateLastMessage(conversationId: ConversationID, message: Message) async throws {
        guard var conversation = conversations[conversationId] else { return }
        conversation.lastMessage = message
        conversation.updatedAt = message.effectiveTimestamp
        if message.direction == .incoming, message.status != .read { conversation.unreadCount += 1 }
        conversations[conversationId] = conversation
        emitConversations()
    }

    func setUnread(conversationId: ConversationID, count: Int) async throws {
        guard var conversation = conversations[conversationId] else { return }
        conversation.unreadCount = count
        conversations[conversationId] = conversation
        emitConversations()
    }

    func delete(id: ConversationID) async throws {
        conversations.removeValue(forKey: id)
        for message in messages.values where message.conversationId == id { messages.removeValue(forKey: message.id) }
        emitConversations()
    }

    // MARK: ContactRepository

    func upsert(_ contact: Contact) async throws {
        contacts[contact.id] = contact
        emitContact(contact.id)
    }

    func fetch(userId: UserID) async throws -> Contact? {
        contacts[userId]
    }

    func fetchAll() async throws -> [Contact] {
        Array(contacts.values)
    }

    func setKeys(userId: UserID, keys: PublicKeyBundle) async throws {
        contacts[userId]?.keys = keys
        emitContact(userId)
    }

    func setTrust(userId: UserID, trust: TrustState) async throws {
        contacts[userId]?.trust = trust
        emitContact(userId)
    }

    func updatePresence(userId: UserID, presence: Presence) async throws {
        contacts[userId]?.presence = presence
        emitContact(userId)
    }

    func observe(userId: UserID) async -> AsyncStream<Contact> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<Contact>.makeStream()
        contactObservers[key] = (userId, continuation)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContactObserver(key) }
        }
        if let contact = contacts[userId] { continuation.yield(contact) }
        return stream
    }

    // MARK: Emission

    private func sorted(in conversationId: ConversationID) -> [Message] {
        messages.values.filter { $0.conversationId == conversationId }.sorted { $0.effectiveTimestamp < $1.effectiveTimestamp }
    }

    private func emitMessages(for conversationId: ConversationID) {
        let snapshot = sorted(in: conversationId)
        for (id, continuation) in messageObservers.values where id == conversationId {
            continuation.yield(snapshot)
        }
    }

    private func emitConversations() {
        let snapshot = conversations.values.sorted { $0.updatedAt > $1.updatedAt }
        for continuation in conversationObservers.values { continuation.yield(snapshot) }
    }

    private func emitContact(_ userId: UserID) {
        guard let contact = contacts[userId] else { return }
        for (id, continuation) in contactObservers.values where id == userId { continuation.yield(contact) }
        for (conversationId, conversation) in conversations where conversation.contact.id == userId {
            conversations[conversationId]?.contact = contact
        }
        emitConversations()
    }

    private func removeMessageObserver(_ key: UUID) { messageObservers.removeValue(forKey: key) }
    private func removeConversationObserver(_ key: UUID) { conversationObservers.removeValue(forKey: key) }
    private func removeContactObserver(_ key: UUID) { contactObservers.removeValue(forKey: key) }
}
