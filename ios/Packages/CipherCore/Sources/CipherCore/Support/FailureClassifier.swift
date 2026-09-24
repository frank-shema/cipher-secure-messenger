import Foundation

/// Adopted by transport-layer errors (the networking module's `APIError`) so Core can tell a failure
/// that is likely to succeed on retry (offline, timeout, 5xx, 429) from one that will not (4xx).
public protocol RetryableError: Error {
    var isRetryable: Bool { get }
}

/// Decides whether a failed send stays queued for a later outbox flush or is surfaced as failed.
public enum FailureClassifier {
    /// Unknown error types are treated as permanent on purpose: the person then sees a retry
    /// affordance right away instead of a message that silently spins forever.
    public static func isTransient(_ error: any Error) -> Bool {
        if let retryable = error as? any RetryableError {
            return retryable.isRetryable
        }
        return error is URLError || error is CancellationError
    }
}
