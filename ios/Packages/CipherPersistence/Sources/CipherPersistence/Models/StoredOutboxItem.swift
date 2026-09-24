import Foundation
import SwiftData

/// A sealed envelope that has not been acknowledged by the relay. Survives relaunches so an offline
/// send is retried instead of lost; FIFO by `enqueuedAt` so counters arrive in order.
@Model
final class StoredOutboxItem {
    @Attribute(.unique) var messageId: UUID
    /// Encoded `Envelope` JSON, ready to send verbatim.
    @Attribute(.externalStorage) var envelope: Data
    var enqueuedAt: Date
    var attempts: Int
    /// Error type name of the last failure; never a description.
    var lastError: String?
    var lastAttemptAt: Date?

    init(messageId: UUID, envelope: Data, enqueuedAt: Date, attempts: Int, lastError: String?, lastAttemptAt: Date?) {
        self.messageId = messageId
        self.envelope = envelope
        self.enqueuedAt = enqueuedAt
        self.attempts = attempts
        self.lastError = lastError
        self.lastAttemptAt = lastAttemptAt
    }
}
