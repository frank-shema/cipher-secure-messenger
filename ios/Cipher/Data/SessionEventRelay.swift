import CipherCore
import Foundation

/// Carries session changes that originate below the UI (a background token refresh, a rejected refresh)
/// up to `AppSession`, which owns the visible sign-in state.
///
/// A stream rather than a callback because the producer is an actor created before the session object
/// exists, and because the session must observe from the main actor; the stream buffers a burst of
/// events while the consumer is busy without either side knowing about the other's isolation.
final class SessionEventRelay: Sendable {
    enum Event: Hashable, Sendable {
        /// The refresh token was exchanged; the new session is already saved in the Keychain.
        case refreshed(Session)
        /// The relay rejected the refresh token: the person is effectively signed out.
        case invalidated
    }

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(of: Event.self, bufferingPolicy: .bufferingNewest(16))
    }

    func send(_ event: Event) {
        continuation.yield(event)
    }
}
