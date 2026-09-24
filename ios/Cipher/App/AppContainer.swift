import CipherCore
import CipherDesign
import Foundation
import Observation

/// The composition root. Everything with a lifetime of "the whole process" is built exactly once here
/// and handed down through the SwiftUI environment; everything with a lifetime of "one signed-in
/// account" is built by `makeMessagingStack(for:)` when the session becomes ready.
///
/// Production wiring lives in `ProductionFactories`; previews and tests use `mock()`, which swaps every
/// port for an in-memory implementation so no screen ever needs a relay, a Keychain or CryptoKit.
@MainActor
@Observable
final class AppContainer {
    let endpoints: ServerEndpoints
    let defaults: UserDefaults
    let clock: any Clock
    let sessionStore: any SessionStore
    let authGateway: any AuthGateway
    let keyDirectory: any KeyDirectoryGateway
    let identityKeyStore: any IdentityKeyStore
    let publicationRegistry: IdentityPublicationRegistry
    let sessionEvents: SessionEventRelay
    let realtimeLifecycle: any RealtimeLifecycle
    let haptics: any HapticEngine
    let toastCenter: ToastCenter
    let router: Router
    let keyPublishClassifier: KeyPublishErrorClassifier

    /// EXTENSION POINT for the messaging integration. Given a ready session, builds the account-scoped
    /// `PersistenceStore`, the `CipherCryptoEngine`, the `WebSocketClient` and the remote gateways, and
    /// returns them as one `MessagingStack`. The default throws `IntegrationError.notWired` so the shell
    /// keeps running (and previews keep compiling) until the integrator assigns the real factory.
    @ObservationIgnored var messagingStackFactory: @Sendable (Session) async throws -> MessagingStack

    init(
        endpoints: ServerEndpoints,
        defaults: UserDefaults,
        clock: any Clock,
        sessionStore: any SessionStore,
        authGateway: any AuthGateway,
        keyDirectory: any KeyDirectoryGateway,
        identityKeyStore: any IdentityKeyStore,
        sessionEvents: SessionEventRelay,
        realtimeLifecycle: any RealtimeLifecycle,
        haptics: any HapticEngine,
        keyPublishClassifier: KeyPublishErrorClassifier = .problemBased,
        messagingStackFactory: @escaping @Sendable (Session) async throws -> MessagingStack = AppContainer.notWiredMessagingStack
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
        self.realtimeLifecycle = realtimeLifecycle
        self.haptics = haptics
        self.toastCenter = ToastCenter()
        self.router = Router()
        self.keyPublishClassifier = keyPublishClassifier
        self.messagingStackFactory = messagingStackFactory
    }

    /// The production graph: Keychain-backed stores and the relay at the configured (or overridden) address.
    static func live(defaults: UserDefaults = .standard) -> AppContainer {
        let endpoints = AppPreferences.endpoints(in: defaults)
        let clock = SystemClock()
        let sessionEvents = SessionEventRelay()
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
            realtimeLifecycle: ports.realtimeLifecycle,
            haptics: CoreHapticsEngine()
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
            realtimeLifecycle: NoopRealtimeLifecycle(),
            haptics: NoopHapticEngine()
        )
    }

    var identityBootstrapper: IdentityBootstrapper {
        IdentityBootstrapper(keyStore: identityKeyStore, directory: keyDirectory, classifier: keyPublishClassifier)
    }

    /// Builds the account-scoped messaging graph; see `messagingStackFactory`.
    func makeMessagingStack(for session: Session) async throws -> MessagingStack {
        AppLog.container.info("building messaging stack for \(session.user.id.description, privacy: .public)")
        return try await messagingStackFactory(session)
    }

    @Sendable
    private static func notWiredMessagingStack(for session: Session) async throws -> MessagingStack {
        throw IntegrationError.notWired(component: "CipherPersistence.PersistenceStore + CipherCrypto.CipherCryptoEngine")
    }
}
