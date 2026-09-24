import os

/// A reference that is bound once, after construction, and read many times.
///
/// The composition root has one genuine cycle: the token provider needs the auth gateway to refresh a
/// session, while the API client that backs the auth gateway needs the token provider to sign requests.
/// Binding the gateway late breaks the cycle without making either side optional in its API, and the
/// lock keeps the single write visible to every later read from any executor.
final class LateBound<Value: Sendable>: Sendable {
    private let storage: OSAllocatedUnfairLock<Value?>

    init() {
        storage = OSAllocatedUnfairLock(initialState: nil)
    }

    /// The bound value, or nil until `bind(_:)` has been called.
    var value: Value? {
        storage.withLock { $0 }
    }

    func bind(_ value: Value) {
        storage.withLock { $0 = value }
    }
}
