import Foundation

/// Progress of a single upload or download as a stream of fractions in `0...1`. Create one, hand it to
/// the gateway call, and iterate `updates` from a task of your own. Only the newest value is buffered:
/// a UI that falls behind should jump to the current fraction, not replay every intermediate step.
public final class TransferProgress: Sendable {
    public let updates: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<Double>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.updates = stream
        self.continuation = continuation
    }

    /// Reports a new fraction. Out-of-range values are clamped so a server that misreports
    /// `Content-Length` cannot push a progress ring past full.
    public func report(_ fraction: Double) {
        let clamped = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        continuation.yield(clamped)
    }

    /// Reports completed and finished bytes, tolerating an unknown total.
    public func report(completed: Int64, total: Int64) {
        guard total > 0 else { return }
        report(Double(completed) / Double(total))
    }

    /// Ends the stream. Called by the client on success and on failure so observers always terminate.
    public func finish() {
        continuation.finish()
    }
}
