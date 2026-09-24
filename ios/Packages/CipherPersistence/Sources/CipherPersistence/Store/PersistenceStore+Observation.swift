import CipherCore
import Foundation

/// Observation re-queries the store after every relevant mutation instead of diffing rows. That is
/// slower than incremental updates but cannot drift: whatever the stream emits is exactly what a
/// fresh fetch would return at that moment.
extension PersistenceStore {
    public func observe(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        observation(filter: .messages(conversationId)) { [self] () throws(PersistenceError) in
            try await messagesSnapshot(conversationId: conversationId)
        }
    }

    public func observeAll() async -> AsyncStream<[Conversation]> {
        observation(filter: .conversations) { [self] () throws(PersistenceError) in
            try await conversationsSnapshot()
        }
    }

    /// Emits nothing until the contact exists; a stream of optionals would force every caller to
    /// handle a state the UI has no representation for.
    public func observe(userId: UserID) async -> AsyncStream<Contact> {
        observation(filter: .contact(userId)) { [self] () throws(PersistenceError) in
            try await contactSnapshot(userId: userId)
        }
    }

    /// Builds a stream that runs `query` once immediately and again after every change matching
    /// `filter`. Cancelling the consumer, or dropping the stream, cancels the pump task and removes
    /// the subscription, so an abandoned screen costs nothing.
    private nonisolated func observation<Value: Sendable>(
        filter: PersistenceChangeFilter,
        query: @escaping @Sendable () async throws(PersistenceError) -> Value?
    ) -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let subscription = notifier.subscribe(filter)
        let notifier = notifier
        let task = Task {
            await Self.pump(subscription.changes, into: continuation, query: query)
        }
        continuation.onTermination = { _ in
            task.cancel()
            notifier.unsubscribe(subscription.id)
        }
        return stream
    }

    private static func pump<Value: Sendable>(
        _ changes: AsyncStream<Void>,
        into continuation: AsyncStream<Value>.Continuation,
        query: @escaping @Sendable () async throws(PersistenceError) -> Value?
    ) async {
        guard await emit(continuation, query: query) else { return }
        for await _ in changes {
            guard !Task.isCancelled, await emit(continuation, query: query) else { return }
        }
        continuation.finish()
    }

    /// A failing query ends the stream rather than skipping silently: the consumer then knows the
    /// data is gone, instead of sitting on a stale list that will never refresh.
    private static func emit<Value: Sendable>(
        _ continuation: AsyncStream<Value>.Continuation,
        query: @Sendable () async throws(PersistenceError) -> Value?
    ) async -> Bool {
        do {
            if let value = try await query() {
                continuation.yield(value)
            }
            return true
        } catch {
            PersistenceLog.observation.error("observation query failed: \(PersistenceError.typeName(of: error), privacy: .public)")
            continuation.finish()
            return false
        }
    }
}
