import Foundation

/// Source of the random component of a reconnect delay. Injected so the client's timing is
/// deterministic under test; production uses the system generator.
public protocol ReconnectJitter: Sendable {
    func value(in range: ClosedRange<TimeInterval>) -> TimeInterval
}

public struct SystemReconnectJitter: ReconnectJitter {
    public init() {}

    public func value(in range: ClosedRange<TimeInterval>) -> TimeInterval {
        Double.random(in: range)
    }
}

/// Exponential backoff with *full* jitter: the delay for attempt `n` is uniform in
/// `0...min(maxDelay, baseDelay * multiplier^n)`. Full jitter (rather than "delay ± a bit") is what
/// stops every phone that lost the same Wi-Fi from stampeding the relay at the same instant when it
/// comes back. Attempt counting restarts after each successful connect.
public struct ReconnectPolicy: Hashable, Sendable {
    public var baseDelay: TimeInterval
    public var multiplier: Double
    public var maxDelay: TimeInterval

    public init(baseDelay: TimeInterval = 1, multiplier: Double = 2, maxDelay: TimeInterval = 30) {
        self.baseDelay = max(0, baseDelay)
        self.multiplier = max(1, multiplier)
        self.maxDelay = max(self.baseDelay, maxDelay)
    }

    /// 1 s → 2 s → 4 s → … → 30 s.
    public static let `default` = ReconnectPolicy()

    /// The upper bound of the jitter window for a zero-based attempt number. The exponent is clamped
    /// so a client that has been retrying for hours cannot overflow into `inf` or `nan`.
    public func ceiling(forAttempt attempt: Int) -> TimeInterval {
        let exponent = Double(min(max(attempt, 0), 64))
        return min(maxDelay, baseDelay * pow(multiplier, exponent))
    }

    /// Delay for `attempt` using an injected jitter source.
    public func delay(forAttempt attempt: Int, jitter: any ReconnectJitter) -> TimeInterval {
        jitter.value(in: 0...ceiling(forAttempt: attempt))
    }

    /// Delay for `attempt` drawn from a caller-owned generator, for seeded, reproducible sequences.
    public func delay<G: RandomNumberGenerator>(forAttempt attempt: Int, using generator: inout G) -> TimeInterval {
        Double.random(in: 0...ceiling(forAttempt: attempt), using: &generator)
    }
}
