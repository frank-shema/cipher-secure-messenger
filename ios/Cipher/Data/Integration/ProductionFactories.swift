import CipherCore
import CipherCrypto
import CipherNetworking
import CipherPersistence
import Foundation

/// Builds the production ports the composition root wires together: the relay client and gateways,
/// the Keychain-backed stores, and, per signed-in account, the persistence store, the crypto engine
/// and the WebSocket assembled into one `MessagingStack`.
enum ProductionFactories {
    /// Process-lifetime ports. `Sendable` so the account factory can capture it from any executor.
    struct Ports: Sendable {
        let apiConfiguration: APIConfiguration
        let client: APIClient
        let sessionStore: any SessionStore
        let authGateway: any AuthGateway
        let keyDirectory: any KeyDirectoryGateway
        /// The Keychain identity, typed concretely because the crypto engine needs its private halves.
        let identityKeys: KeychainIdentityKeyStore
        let tokenProvider: AuthTokenProviderAdapter
        /// The adapter wrapped so concurrent 401s share one refresh; hand this to `APIClient` and
        /// `WebSocketClient`, never the bare adapter.
        let networkTokenProvider: any AuthTokenProvider

        var identityKeyStore: any IdentityKeyStore { identityKeys }
    }

    static func makePorts(endpoints: ServerEndpoints, sessionEvents: SessionEventRelay, clock: any Clock) -> Ports {
        let apiConfiguration = APIConfiguration(baseURL: endpoints.baseURL, webSocketURL: endpoints.webSocketURL)
        let sessionStore = KeychainSessionStore()
        let authGatewayBinding = LateBound<any AuthGateway>()
        let tokenProvider = AuthTokenProviderAdapter(
            sessionStore: sessionStore,
            authGateway: authGatewayBinding,
            clock: clock,
            onSessionRefreshed: { session in sessionEvents.send(.refreshed(session)) },
            onRefreshRejected: { sessionEvents.send(.invalidated) }
        )
        let networkTokenProvider = CoalescingAuthTokenProvider(tokenProvider)
        let client = APIClient(configuration: apiConfiguration, tokenProvider: networkTokenProvider, clock: clock)

        // The auth routes never consult the token provider, so the same client serves the gateway the
        // provider refreshes through; binding late breaks the construction cycle.
        let authGateway = RemoteAuthGateway(client: client, clock: clock)
        authGatewayBinding.bind(authGateway)
        let keyDirectory = RemoteKeyDirectoryGateway(client: client)
        let identityKeys = KeychainIdentityKeyStore(service: CipherCrypto.defaultKeychainService)

        let host = apiConfiguration.baseURL.host() ?? "?"
        let secure = apiConfiguration.isTransportSecure
        AppLog.container.info("production ports built for \(host, privacy: .public) secure=\(secure, privacy: .public)")
        return Ports(
            apiConfiguration: apiConfiguration,
            client: client,
            sessionStore: sessionStore,
            authGateway: authGateway,
            keyDirectory: keyDirectory,
            identityKeys: identityKeys,
            tokenProvider: tokenProvider,
            networkTokenProvider: networkTokenProvider
        )
    }

    /// The account-scoped graph: an on-disk SwiftData store under the account's own directory
    /// (`NSFileProtectionComplete`), the CryptoKit engine over the Keychain identity, a fresh
    /// WebSocket, and the relay gateway wrapped so raw envelopes reach the Server's-Eye view.
    static func makeMessagingStack(for session: Session, ports: Ports, clock: any Clock) throws -> MessagingStack {
        let store = try PersistenceStore.onDisk(accountId: session.user.id, clock: clock)
        let vault = EnvelopeVault()
        let gateway = RecordingConversationGateway(base: RemoteConversationGateway(client: ports.client), vault: vault)
        let realtime = WebSocketClient(configuration: ports.apiConfiguration, tokenProvider: ports.networkTokenProvider)
        AppLog.container.info("account stack ready for \(session.user.id.description, privacy: .public)")
        return MessagingStack(
            account: session.user,
            messages: store,
            conversations: store,
            contacts: store,
            outbox: store,
            replayGuard: PersistedReplayGuard(store: store),
            crypto: CipherCryptoEngine(keyProvider: ports.identityKeys),
            keyDirectory: ports.keyDirectory,
            conversationGateway: gateway,
            realtime: realtime,
            clock: clock,
            envelopes: StoredEnvelopeProvider(store: store, vault: vault),
            disappearingTimers: store,
            expiredMessages: store,
            rawEnvelopes: store
        )
    }

    /// Sign-out hook: removes the account's store directory. Identity keys stay in the Keychain so a
    /// later sign-in on this device reuses them; only messages, contacts and counters leave.
    static func removeAccountData(_ accountId: UserID) throws {
        try PersistenceConfiguration.removeOnDiskStore(accountId: accountId)
        AppLog.container.notice("removed local data for \(accountId.description, privacy: .public)")
    }
}
