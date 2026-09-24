import Foundation

/// Pulls history newest-first until a page contains messages already stored, feeding unknown
/// envelopes through `ReceiveEnvelopeUseCase` (own envelopes included: the sender can open their own
/// history because the message key derives from the sender id). Known outgoing envelopes have their
/// relay status reconciled, which recovers receipts missed while offline.
public struct SyncConversationUseCase: Sendable {
    private let currentUserId: UserID
    private let gateway: any ConversationGateway
    private let messages: any MessageRepository
    private let receive: ReceiveEnvelopeUseCase
    private let pageSize: Int
    private let maxPages: Int

    public init(
        currentUserId: UserID,
        gateway: any ConversationGateway,
        messages: any MessageRepository,
        receive: ReceiveEnvelopeUseCase,
        pageSize: Int = 50,
        maxPages: Int = 40
    ) {
        self.currentUserId = currentUserId
        self.gateway = gateway
        self.messages = messages
        self.receive = receive
        self.pageSize = pageSize
        self.maxPages = maxPages
    }

    /// Returns the newly stored messages, oldest first.
    public func execute(conversationId: ConversationID) async throws -> [Message] {
        var received: [Message] = []
        var before: Date?
        for _ in 0..<maxPages {
            let page = try await gateway.fetchMessages(conversationId: conversationId, before: before, limit: pageSize)
            let known = try await messages.knownIds(among: page.items.map(\.id))
            for stored in page.items.reversed() where !known.contains(stored.id) {
                let message = try await receive.execute(stored)
                received.append(message)
            }
            try await reconcile(page.items.filter { known.contains($0.id) && $0.envelope.senderId == currentUserId })
            guard page.hasMore, known.isEmpty, let oldest = page.items.last else { break }
            before = oldest.serverCreatedAt
        }
        CoreLog.useCases.info("synced \(received.count) messages for \(conversationId.description, privacy: .public)")
        return received.sorted { $0.effectiveTimestamp < $1.effectiveTimestamp }
    }

    private func reconcile(_ known: [StoredEnvelope]) async throws {
        for status in DeliveryStatus.allCases {
            let matching = known.filter { $0.status == status }
            guard let latest = matching.map(\.statusChangedAt).max() else { continue }
            try await messages.updateStatus(ids: matching.map(\.id), status: status.messageStatus, at: latest)
        }
    }
}
