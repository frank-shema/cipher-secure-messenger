import CipherCore
import CipherDesign
import Foundation
import Observation

/// The composition root. Everything with a lifetime of "the whole process" is built exactly once here
/// and handed down through the SwiftUI environment; everything with a lifetime of "one signed-in
/// account" is built by `runtimeFactory` when the session becomes ready and owned by `messaging`.
///
/// Production wiring lives in `ProductionFactories`; previews and tests use `mock()`, which swaps every
/// port for an in-memory implementation so no screen ever needs a relay, a Keychain or CryptoKit.
@MainActor
@Observable
final class AppContainer {
    typealias RuntimeFactory = @MainActor (Session, AppContainer) async throws -> any ActiveMessaging

    let endpoints: ServerEndpoints
    let defaults: UserDefaults
    let clock: any Clock
    let sessionStore: any SessionStore
    let authGateway: any AuthGateway
    let keyDirectory: any KeyDirectoryGateway
    let identityKeyStore: any IdentityKeyStore
    let publicationRegistry: IdentityPublicationRegistry
    let sessionEvents: SessionEventRelay
    let haptics: any HapticEngine
    let toastCenter: ToastCenter
    let router: Router
    let appLock: AppLockManager
    let flipToHide: FlipToHideMonitor
    let messaging: MessagingCoordinator
    let keyPublishClassifier: KeyPublishErrorClassifier

    /// Builds the account-scoped Core graph (`PersistenceStore`, `CipherCryptoEngine`, `WebSocketClient`,
    /// remote gateways). Kept as a standalone factory because the DEBUG self-test drives a stack directly.
    @ObservationIgnored var messagingStackFactory: @Sendable (Session) async throws -> MessagingStack
    /// Wraps a stack into the runtime the screens run on; previews substitute the in-memory fakes.
    @ObservationIgnored var runtimeFactory: RuntimeFactory

    init(
        endpoints: ServerEndpoints,
        defaults: UserDefaults,
        clock: any Clock,
        sessionStore: any SessionStore,
        authGateway: any AuthGateway,
        keyDirectory: any KeyDirectoryGateway,
        identityKeyStore: any IdentityKeyStore,
        sessionEvents: SessionEventRelay,
        haptics: any HapticEngine,
        appLock: AppLockManager,
        flipToHide: FlipToHideMonitor,
        keyPublishClassifier: KeyPublishErrorClassifier = .problemBased,
        messagingStackFactory: @escaping @Sendable (Session) async throws -> MessagingStack = AppContainer.notWiredMessagingStack,
        runtimeFactory: @escaping RuntimeFactory = AppContainer.liveRuntime,
        wipeAccountData: @escaping @Sendable (UserID) throws -> Void = { _ in }
    ) {
        self.endpoints = endpoints
        self.defaults = defaults
        self.clock = clock
        self.sessionStore = sessionStore
        self.authGateway = authGateway
        self.keyDirectory = keyDirectory
        self.identityKeyStore = identityKeyStore
        self.publicationRegistry = IdentityPublicationRegistry(defaults: defaults)
        self.sessionEvents = sessionEvents
        self.haptics = haptics
        self.toastCenter = ToastCenter()
        self.router = Router()
        self.appLock = appLock
        self.flipToHide = flipToHide
        self.keyPublishClassifier = keyPublishClassifier
        self.messagingStackFactory = messagingStackFactory
        self.runtimeFactory = runtimeFactory
        self.messaging = MessagingCoordinator(
            router: router,
            appLock: appLock,
            identityKeys: identityKeyStore,
            clock: clock,
            wipeAccountData: wipeAccountData
        )
        messaging.makeRuntime = { [weak self] session in
            guard let self else { throw IntegrationError.notWired(component: "AppContainer") }
            return try await self.runtimeFactory(session, self)
        }
    }

    /// The production graph: Keychain-backed stores and the relay at the configured (or overridden) address.
    static func live(defaults: UserDefaults = .standard) -> AppContainer {
        let endpoints = AppPreferences.endpoints(in: defaults)
        let clock = SystemClock()
        let sessionEvents = SessionEventRelay()
        let haptics = CoreHapticsEngine()
        let ports = ProductionFactories.makePorts(endpoints: endpoints, sessionEvents: sessionEvents, clock: clock)
        return AppContainer(
            endpoints: endpoints,
            defaults: defaults,
            clock: clock,
            sessionStore: ports.sessionStore,
            authGateway: ports.authGateway,
            keyDirectory: ports.keyDirectory,
            identityKeyStore: ports.identityKeyStore,
            sessionEvents: sessionEvents,
            haptics: haptics,
            appLock: AppLockManager.live(haptics: haptics, defaults: defaults),
            flipToHide: FlipToHideMonitor(defaults: defaults),
            messagingStackFactory: { session in
                try ProductionFactories.makeMessagingStack(for: session, ports: ports, clock: clock)
            },
            wipeAccountData: { accountId in try ProductionFactories.removeAccountData(accountId) }
        )
    }

    /// An in-memory graph for previews. `signedInAs` pre-loads a session so a preview can start past
    /// onboarding; `keysPublished` decides whether that account lands on key generation or the inbox.
    static func mock(
        signedInAs user: User? = nil,
        keysPublished: Bool = true,
        keyUpload: MockKeyDirectoryGateway.UploadBehavior = .accept
    ) -> AppContainer {
        let defaults = UserDefaults(suiteName: "com.cipher.preview.\(UUID().uuidString)") ?? .standard
        let registry = IdentityPublicationRegistry(defaults: defaults)
        var existingKeys: PublicKeyBundleUpload?
        if let user, keysPublished {
            registry.markPublished(user.id)
            let bundle = Fixtures.keyBundle(for: user)
            existingKeys = PublicKeyBundleUpload(identityKey: bundle.identityKey, signingKey: bundle.signingKey)
        }
        return AppContainer(
            endpoints: .localhost,
            defaults: defaults,
            clock: SystemClock(),
            sessionStore: MockSessionStore(session: user.map { Fixtures.session(for: $0) }),
            authGateway: MockAuthGateway(),
            keyDirectory: MockKeyDirectoryGateway(currentUser: user ?? Fixtures.alice, uploadBehavior: keyUpload),
            identityKeyStore: MockIdentityKeyStore(existing: existingKeys),
            sessionEvents: SessionEventRelay(),
            haptics: NoopHapticEngine(),
            appLock: AppLockManager.preview(enabled: false, locked: false),
            flipToHide: FlipToHideMonitor(source: PreviewGravitySource(), defaults: defaults),
            runtimeFactory: { session, _ in PreviewMessagingRuntime(session: session) }
        )
    }

    var identityBootstrapper: IdentityBootstrapper {
        IdentityBootstrapper(keyStore: identityKeyStore, directory: keyDirectory, classifier: keyPublishClassifier)
    }

    /// The realtime hooks `AppSession` fires; the messaging coordinator answers them.
    var realtimeLifecycle: any RealtimeLifecycle { messaging }

    /// Builds the account-scoped messaging graph; see `messagingStackFactory`.
    func makeMessagingStack(for session: Session) async throws -> MessagingStack {
        AppLog.container.info("building messaging stack for \(session.user.id.description, privacy: .public)")
        return try await messagingStackFactory(session)
    }

    @Sendable
    private static func notWiredMessagingStack(for session: Session) async throws -> MessagingStack {
        throw IntegrationError.notWired(component: "CipherPersistence.PersistenceStore + CipherCrypto.CipherCryptoEngine")
    }

    /// Production runtime: the real stack behind a socket pump, expiry sweeps and the sensitive guard.
    private static func liveRuntime(for session: Session, in container: AppContainer) async throws -> any ActiveMessaging {
        let stack = try await container.makeMessagingStack(for: session)
        return AccountRuntime(
            stack: stack,
            identityKeys: container.identityKeyStore,
            haptics: container.haptics,
            toasts: container.toastCenter,
            defaults: container.defaults
        )
    }
}
