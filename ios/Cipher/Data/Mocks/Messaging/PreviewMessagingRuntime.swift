import CipherCore
import Foundation

/// The preview stand-in for `AccountRuntime`: the in-memory messaging fakes (seeded threads, an echo
/// companion, synthetic envelopes) behind the same surface the real screens use. No socket, no
/// sweeps; the lifecycle hooks only report a connected banner state.
@MainActor
final class PreviewMessagingRuntime: ActiveMessaging {
    let surface: MessagingSurface
    var onConnectionChange: @MainActor (RealtimeConnectionState) -> Void = { _ in }

    init(session: Session, seeded: Bool = true) {
        let bundle = PreviewMessaging.bundle(seeded: seeded)
        surface = MessagingSurface(
            account: session.user,
            list: bundle.list,
            chat: bundle.chat,
            verify: VerifyPreviews.dependencies(store: bundle.store),
            isDecoy: false
        )
    }

    func start() async {
        onConnectionChange(.connected)
    }

    func stop() async {}

    func suspend() async {}

    func resume() async {
        onConnectionChange(.connected)
    }
}
