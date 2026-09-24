import CipherCore
import Foundation
import os

/// What a mutation touched. Observers re-query after a notice, so a change carries scope only and
/// never data: the fresh query is the single source of truth and there is nothing to keep in sync.
enum PersistenceChange: Hashable, Sendable {
    /// Message rows of one conversation were added, changed or removed.
    case messages(ConversationID)
    /// A conversation row or its settings changed.
    case conversations
    /// A contact's user, keys, trust or presence changed.
    case contact(UserID)
}

/// What an observer wants to be told about.
enum PersistenceChangeFilter: Hashable, Sendable {
    case messages(ConversationID)
    case conversations
    case contact(UserID)

    /// Inbox rows show the contact's name and presence plus the last message, so the conversation
    /// list is refreshed for every kind of change; the narrower filters match their own scope only.
    func matches(_ change: PersistenceChange) -> Bool {
        switch (self, change) {
        case (.conversations, _):
            true
        case (.messages(let mine), .messages(let theirs)):
            mine == theirs
        case (.contact(let mine), .contact(let theirs)):
            mine == theirs
        default:
            false
        }
    }
}

/// Fans mutation notices out to observation streams. A lock rather than an actor so publishing is
/// synchronous from inside the store: with no suspension point between saving and notifying, an
/// observer can never re-query before a change it was told about has reached the context.
final class ChangeNotifier: Sendable {
    struct Subscription: Sendable {
        let id: UUID
        let changes: AsyncStream<Void>
    }

    private struct Subscriber: Sendable {
        let filter: PersistenceChangeFilter
        let continuation: AsyncStream<Void>.Continuation
    }

    private let subscribers = OSAllocatedUnfairLock<[UUID: Subscriber]>(initialState: [:])

    /// Returns a stream that yields once per matching change. Only the newest notice is buffered
    /// because observers re-query in full, so several changes in a row collapse into one refresh.
    func subscribe(_ filter: PersistenceChangeFilter) -> Subscription {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let active = subscribers.withLock { table in
            table[id] = Subscriber(filter: filter, continuation: continuation)
            return table.count
        }
        PersistenceLog.observation.debug("observer added; active=\(active, privacy: .public)")
        return Subscription(id: id, changes: stream)
    }

    func unsubscribe(_ id: UUID) {
        let removed = subscribers.withLock { $0.removeValue(forKey: id) }
        removed?.continuation.finish()
        if removed != nil {
            PersistenceLog.observation.debug("observer removed")
        }
    }

    func publish(_ changes: [PersistenceChange]) {
        guard !changes.isEmpty else { return }
        subscribers.withLock { table in
            for subscriber in table.values where changes.contains(where: subscriber.filter.matches) {
                subscriber.continuation.yield(())
            }
        }
    }
}
