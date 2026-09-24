import Foundation

/// Injected time source so use cases are deterministic under test.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

/// Injected id source so tests can assert on exact identifiers.
public protocol UUIDGenerator: Sendable {
    func next() -> UUID
}

public struct SystemUUIDGenerator: UUIDGenerator {
    public init() {}

    public func next() -> UUID {
        UUID()
    }
}
