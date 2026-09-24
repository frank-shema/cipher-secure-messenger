import CipherCore
import Foundation
import SwiftData

extension PersistenceStore: ReplayGuard {
    public func isReplay(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws(PersistenceError) -> Bool {
        try seenRow(senderId: senderId, conversationId: conversationId, counter: counter) != nil
    }

    public func markSeen(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws(PersistenceError) {
        guard try seenRow(senderId: senderId, conversationId: conversationId, counter: counter) == nil else { return }
        let value = Int64(bitPattern: counter)
        let row = StoredSeenCounter(
            key: StoredSeenCounter.makeKey(senderId: senderId.uuid, conversationId: conversationId.uuid, counter: value),
            senderId: senderId.uuid,
            conversationId: conversationId.uuid,
            counter: value,
            seenAt: now
        )
        modelContext.insert(row)
        try commit([])
    }

    private func seenRow(senderId: UserID, conversationId: ConversationID, counter: UInt64) throws(PersistenceError) -> StoredSeenCounter? {
        let value = Int64(bitPattern: counter)
        let key = StoredSeenCounter.makeKey(senderId: senderId.uuid, conversationId: conversationId.uuid, counter: value)
        return try fetchFirst(#Predicate<StoredSeenCounter> { $0.key == key })
    }
}

/// The persisted replay guard under the name the architecture uses for it. A thin handle so the
/// composition root can inject only the guard where a use case needs nothing else from the store.
public struct PersistedReplayGuard: ReplayGuard, Sendable {
    private let store: PersistenceStore

    public init(store: PersistenceStore) {
        self.store = store
    }

    public func isReplay(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws(PersistenceError) -> Bool {
        try await store.isReplay(senderId: senderId, conversationId: conversationId, counter: counter)
    }

    public func markSeen(senderId: UserID, conversationId: ConversationID, counter: UInt64) async throws(PersistenceError) {
        try await store.markSeen(senderId: senderId, conversationId: conversationId, counter: counter)
    }
}
