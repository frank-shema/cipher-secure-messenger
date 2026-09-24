import CipherCore
import Foundation

/// Remembers the wire envelopes that crossed the gateway, keyed by message id, so the Server's-Eye view
/// can show exactly what the relay stored even for messages whose row did not exist yet when the
/// envelope arrived (history pages are received before `ReceiveEnvelopeUseCase` persists them).
///
/// Bounded and in-memory: it is a staging area, not a store. `StoredEnvelopeProvider` moves each
/// envelope into persistence the first time it is asked for.
actor EnvelopeVault {
    private let capacity: Int
    private var envelopes: [MessageID: Envelope] = [:]
    private var order: [MessageID] = []

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    func remember(_ batch: [Envelope]) {
        for envelope in batch where envelopes[envelope.id] == nil {
            envelopes[envelope.id] = envelope
            order.append(envelope.id)
        }
        while order.count > capacity {
            let evicted = order.removeFirst()
            envelopes.removeValue(forKey: evicted)
        }
    }

    func envelope(for id: MessageID) -> Envelope? {
        envelopes[id]
    }

    var count: Int {
        envelopes.count
    }
}

/// Wraps the relay gateway so every envelope it serves or accepts lands in the vault. Behaviour is
/// otherwise untouched: the decorator never inspects or alters what passes through.
struct RecordingConversationGateway: ConversationGateway {
    private let base: any ConversationGateway
    private let vault: EnvelopeVault

    init(base: any ConversationGateway, vault: EnvelopeVault) {
        self.base = base
        self.vault = vault
    }

    func createOrGet(participantId: UserID) async throws -> RemoteConversation {
        try await base.createOrGet(participantId: participantId)
    }

    func list() async throws -> [RemoteConversation] {
        try await base.list()
    }

    func fetchMessages(conversationId: ConversationID, before: Date?, limit: Int) async throws -> MessagePage {
        let page = try await base.fetchMessages(conversationId: conversationId, before: before, limit: limit)
        await vault.remember(page.items.map(\.envelope))
        return page
    }

    func send(_ envelope: Envelope) async throws -> MessageAck {
        await vault.remember([envelope])
        return try await base.send(envelope)
    }
}

/// Fallback `EnvelopeProviding` for stacks without a raw-envelope store (previews, the DEBUG bot):
/// only envelopes still queued in the outbox can be shown.
struct OutboxEnvelopeProvider: EnvelopeProviding {
    private let outbox: any OutboxRepository

    init(outbox: any OutboxRepository) {
        self.outbox = outbox
    }

    func envelope(for messageId: MessageID) async throws -> Envelope? {
        try await outbox.item(messageId: messageId)?.envelope
    }
}
