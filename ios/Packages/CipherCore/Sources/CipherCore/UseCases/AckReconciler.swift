import Foundation

/// The one place that turns a relay answer (or failure) into local state, shared by the first send,
/// manual retries and the outbox flush so all three agree on what "sent" and "failed" mean.
struct AckReconciler: Sendable {
    enum Outcome: Sendable {
        /// Acknowledged; the outbox item is gone.
        case sent(Message)
        /// Transient failure; the item stays queued and the message keeps its status.
        case deferred(Message)
        /// Permanent failure; the message is marked `failed` and the item removed.
        case rejected(Message, any Error)
    }

    let messages: any MessageRepository
    let conversations: any ConversationRepository
    let outbox: any OutboxRepository
    let clock: any Clock

    func send(_ envelope: Envelope, for message: Message, via gateway: any ConversationGateway) async throws -> Outcome {
        let ack: MessageAck
        do {
            ack = try await gateway.send(envelope)
        } catch {
            return try await handleFailure(error, for: message)
        }
        let updated = try await apply(ack, to: message)
        try await outbox.remove(messageId: message.id)
        CoreLog.useCases.info(
            "message \(message.id.description, privacy: .public) acknowledged as \(ack.status.rawValue, privacy: .public)"
        )
        return .sent(updated)
    }

    /// Applies the ack without downgrading: a `receipt.read` over the socket may already have moved
    /// the message past `sent` before the HTTP response arrived.
    func apply(_ ack: MessageAck, to message: Message) async throws -> Message {
        var current = try await messages.fetch(id: message.id) ?? message
        let ackStatus = ack.status.messageStatus
        if current.status.shouldAdvance(to: ackStatus) {
            current.status = ackStatus
        }
        current.serverCreatedAt = ack.createdAt
        try await messages.upsert(current)
        try await refreshLastMessage(current)
        return current
    }

    private func handleFailure(_ error: any Error, for message: Message) async throws -> Outcome {
        let errorName = String(describing: type(of: error))
        try await outbox.markAttempt(messageId: message.id, error: errorName, at: clock.now())
        if FailureClassifier.isTransient(error) {
            CoreLog.useCases.notice("message \(message.id.description, privacy: .public) deferred: \(errorName, privacy: .public)")
            let current = try await messages.fetch(id: message.id) ?? message
            return .deferred(current)
        }
        var failed = try await messages.fetch(id: message.id) ?? message
        if failed.status.shouldAdvance(to: .failed) {
            failed.status = .failed
            try await messages.upsert(failed)
            try await refreshLastMessage(failed)
        }
        try await outbox.remove(messageId: message.id)
        CoreLog.useCases.error("message \(message.id.description, privacy: .public) rejected: \(errorName, privacy: .public)")
        return .rejected(failed, error)
    }

    private func refreshLastMessage(_ message: Message) async throws {
        guard let conversation = try await conversations.fetch(id: message.conversationId),
              conversation.lastMessage?.id == message.id else { return }
        try await conversations.updateLastMessage(conversationId: message.conversationId, message: message)
    }
}
