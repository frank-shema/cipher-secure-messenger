#if DEBUG
import Foundation

/// Races an operation against a deadline. The self-test promises an answer within a fixed budget, and
/// the bot's own start-up must never hang a Settings toggle, so both bound their waits here rather than
/// trusting every network call to time out on its own.
enum DemoBotDeadline {
    static func run<Value: Sendable>(
        seconds: TimeInterval,
        onTimeout: DemoBotError,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw onTimeout
            }
            guard let first = try await group.next() else { throw onTimeout }
            group.cancelAll()
            return first
        }
    }
}
#endif
