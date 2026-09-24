import Foundation

/// A sealed envelope waiting for the relay's acknowledgement.
public struct OutboxItem: Hashable, Codable, Sendable {
    public var messageId: MessageID
    public var envelope: Envelope
    public var enqueuedAt: Date
    public var attempts: Int
    /// Error type name only; never a description that could embed payload data.
    public var lastError: String?

    public init(messageId: MessageID, envelope: Envelope, enqueuedAt: Date, attempts: Int = 0, lastError: String? = nil) {
        self.messageId = messageId
        self.envelope = envelope
        self.enqueuedAt = enqueuedAt
        self.attempts = attempts
        self.lastError = lastError
    }
}

/// Durable queue of unacknowledged sends so an offline send survives a relaunch.
public protocol OutboxRepository: Sendable {
    /// Idempotent by `messageId`.
    func enqueue(_ item: OutboxItem) async throws
    func item(messageId: MessageID) async throws -> OutboxItem?
    /// Oldest first (FIFO), so counters reach the relay in order.
    func pending() async throws -> [OutboxItem]
    func remove(messageId: MessageID) async throws
    func markAttempt(messageId: MessageID, error: String?, at: Date) async throws
}
