import Foundation

/// Runs CPU-bound work on a detached task and hands back its typed result. Sealing, hashing and
/// opening a 25 MB blob must never inherit the caller's executor, which for a send started from a
/// button is the main actor; a detached task guarantees the hop whatever the caller's isolation.
enum BackgroundWork {
    static func run<Success: Sendable, Failure: Error>(
        priority: TaskPriority = .userInitiated,
        _ body: @escaping @Sendable () throws(Failure) -> Success
    ) async throws(Failure) -> Success {
        let outcome: Result<Success, Failure> = await Task.detached(priority: priority) {
            Result(catching: body)
        }.value
        return try outcome.get()
    }
}
