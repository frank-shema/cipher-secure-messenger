import Foundation

/// Drains the outbox oldest-first so counters reach the relay in order. Stops at the first transient
/// failure (the network is down; later items would fail the same way) and drops permanently rejected
/// items after marking their message `failed`.
public struct FlushOutboxUseCase: Sendable {
    public struct Report: Hashable, Sendable {
        public var sent: [MessageID] = []
        public var rejected: [MessageID] = []
        /// Items left queued because the flush stopped early.
        public var deferred: [MessageID] = []

        public init() {}

        public var stoppedEarly: Bool {
            !deferred.isEmpty
        }
    }

    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let outbox: any OutboxRepository
    private let gateway: any ConversationGateway
    private let clock: any Clock

    public init(
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        outbox: any OutboxRepository,
        gateway: any ConversationGateway,
        clock: any Clock = SystemClock()
    ) {
        self.messages = messages
        self.conversations = conversations
        self.outbox = outbox
        self.gateway = gateway
        self.clock = clock
    }

    public func execute() async throws -> Report {
        var report = Report()
        let items = try await outbox.pending()
        let reconciler = AckReconciler(messages: messages, conversations: conversations, outbox: outbox, clock: clock)
        for (index, item) in items.enumerated() {
            guard let message = try await messages.fetch(id: item.messageId) else {
                try await outbox.remove(messageId: item.messageId)
                continue
            }
            switch try await reconciler.send(item.envelope, for: message, via: gateway) {
            case .sent:
                report.sent.append(item.messageId)
            case .rejected:
                report.rejected.append(item.messageId)
            case .deferred:
                report.deferred = items[index...].map(\.messageId)
                CoreLog.useCases.notice("outbox flush stopped with \(report.deferred.count) items queued")
                return report
            }
        }
        return report
    }
}
