import CipherCore
import Foundation
import Observation

/// Owns the active messaging runtime for the signed-in account and decides which surface the
/// screens see. Three things can change it: the session (build or tear down the runtime), the scene
/// phase (connect or disconnect the socket) and the app lock's mode (swap the real inbox for the
/// decoy after a duress unlock, and back after the real PIN).
///
/// While the decoy shows, the real runtime is suspended: no socket, no sweeps, no outbox flush. The
/// relay sees a person who simply went offline, which is the whole point of a duress PIN.
@MainActor
@Observable
final class MessagingCoordinator: RealtimeLifecycle {
    typealias RuntimeFactory = @MainActor (Session) async throws -> any ActiveMessaging

    private(set) var surface: MessagingSurface?
    private(set) var connection: RealtimeConnectionState = .disconnected(retryIn: nil)
    /// Why no surface is available, when the runtime could not be built.
    private(set) var failure: PresentableProblem?
    private(set) var isDecoy = false

    /// Assigned by the container once it exists; the coordinator is created inside the container.
    @ObservationIgnored var makeRuntime: RuntimeFactory = { _ in
        throw IntegrationError.notWired(component: "MessagingCoordinator.makeRuntime")
    }

    @ObservationIgnored private let router: Router
    @ObservationIgnored private let appLock: AppLockManager
    @ObservationIgnored private let identityKeys: any IdentityKeyStore
    @ObservationIgnored private let clock: any Clock
    @ObservationIgnored private let wipeAccountData: @Sendable (UserID) throws -> Void
    @ObservationIgnored private var runtime: (any ActiveMessaging)?
    @ObservationIgnored private var session: Session?

    init(
        router: Router,
        appLock: AppLockManager,
        identityKeys: any IdentityKeyStore,
        clock: any Clock,
        wipeAccountData: @escaping @Sendable (UserID) throws -> Void
    ) {
        self.router = router
        self.appLock = appLock
        self.identityKeys = identityKeys
        self.clock = clock
        self.wipeAccountData = wipeAccountData
    }

    // MARK: RealtimeLifecycle

    func sessionDidBecomeReady(_ session: Session) async {
        self.session = session
        failure = nil
        do {
            let runtime = try await makeRuntime(session)
            runtime.onConnectionChange = { [weak self] state in self?.connection = state }
            self.runtime = runtime
            if appLock.mode.isDecoy {
                await enterDecoy(for: session)
            } else {
                surface = runtime.surface
                await runtime.start()
            }
        } catch {
            AppLog.messaging.error("runtime unavailable: \(String(describing: type(of: error)), privacy: .public)")
            failure = PresentableProblem(error: error)
        }
    }

    func sessionDidEnd(reason: SessionEndReason) async {
        let account = session?.user.id
        await runtime?.stop()
        runtime = nil
        surface = nil
        session = nil
        isDecoy = false
        connection = .disconnected(retryIn: nil)
        guard reason == .signedOut, let account else { return }
        do {
            try wipeAccountData(account)
        } catch {
            AppLog.messaging.error("account data not removed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func applicationDidBecomeActive() async {
        guard !isDecoy else { return }
        await runtime?.resume()
    }

    func applicationDidEnterBackground() async {
        await runtime?.suspend()
    }

    /// Rebuilds the runtime after a failure, for the "try again" button.
    func retry() async {
        guard let session, runtime == nil else { return }
        await sessionDidBecomeReady(session)
    }

    // MARK: Duress

    /// Wired to `AppLockManager.mode` by the root view. Any pushed screen is popped so a real chat can
    /// never survive into the decoy, nor a decoy one into the real inbox.
    func lockModeDidChange(_ mode: AppLockMode) async {
        guard let session, mode.isDecoy != isDecoy else { return }
        router.popToRoot()
        if mode.isDecoy {
            await enterDecoy(for: session)
        } else {
            await leaveDecoy()
        }
    }

    private func enterDecoy(for session: Session) async {
        isDecoy = true
        await runtime?.suspend()
        let clock = clock
        let provider = await DecoyInboxProvider.make(localUserId: session.user.id, now: { clock.now() })
        surface = .decoy(provider, account: session.user, identityKeys: identityKeys, clock: clock)
        connection = .connected
        AppLog.messaging.notice("decoy inbox active")
    }

    private func leaveDecoy() async {
        isDecoy = false
        surface = runtime?.surface
        await runtime?.resume()
        AppLog.messaging.notice("real inbox restored")
    }
}
