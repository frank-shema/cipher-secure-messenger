import Foundation

/// Local view of a message's delivery progress.
public enum MessageStatus: String, Hashable, Codable, Sendable, CaseIterable {
    case sending
    case sent
    case delivered
    case read
    case failed

    private var progressRank: Int {
        switch self {
        case .sending, .failed: 0
        case .sent: 1
        case .delivered: 2
        case .read: 3
        }
    }

    /// Whether applying `next` is not a regression. Receipts and acks can arrive out of order
    /// (a `receipt.read` over the socket may beat the HTTP ack), so stores apply status updates
    /// through this check instead of trusting arrival order. `failed` only replaces `sending`, and a
    /// later successful retry always lifts `failed`.
    public func shouldAdvance(to next: MessageStatus) -> Bool {
        switch (self, next) {
        case (.failed, _):
            return true
        case (_, .failed):
            return self == .sending
        default:
            return next.progressRank >= progressRank
        }
    }
}

public enum MessageDirection: String, Hashable, Codable, Sendable {
    case outgoing
    case incoming
}

/// Server-side status vocabulary (`MessageAck.status`, `StoredEnvelope.status`). Kept separate from
/// `MessageStatus` because the relay can never express `sending` or `failed`.
public enum DeliveryStatus: String, Hashable, Codable, Sendable, CaseIterable {
    case sent = "SENT"
    case delivered = "DELIVERED"
    case read = "READ"

    public var messageStatus: MessageStatus {
        switch self {
        case .sent: .sent
        case .delivered: .delivered
        case .read: .read
        }
    }
}
