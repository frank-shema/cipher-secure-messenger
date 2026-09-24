import CipherCore
import CipherNetworking
import Foundation

/// Builds the production ports the composition root wires together.
///
/// This is the single integration point for the modules that are landing alongside the app shell.
/// Each `NotWired*` value below is a placeholder for one concrete type; replacing it is a one-line
/// change, and until then the shell runs, shows a clear "component missing" banner instead of
/// crashing, and every preview keeps working through `AppContainer.mock()`.
///
/// Wiring plan (types from the other modules):
/// - `APIClient(configuration: apiConfiguration, transport: URLSessionTransport(session: .makeSession()),
///   tokenProvider: networkTokenProvider)` from CipherNetworking.
/// - `RemoteAuthGateway(client:)` and `RemoteKeyDirectoryGateway(client:)` replace the two `NotWired`
///   gateways; bind the auth gateway with `authGatewayBinding.bind(_:)` so token refresh works.
/// - `KeychainIdentityKeyStore(service: "com.cipher.identity")` from CipherCrypto replaces
///   `NotWiredIdentityKeyStore`.
/// - `WebSocketClient` plus `PersistenceStore` are assembled per account in
///   `AppContainer.makeMessagingStack(for:)`, and a `RealtimeLifecycle` that connects/disconnects that
///   socket replaces `NoopRealtimeLifecycle`.
enum ProductionFactories {
    struct Ports {
        let apiConfiguration: APIConfiguration
        let sessionStore: any SessionStore
        let authGateway: any AuthGateway
        let authGatewayBinding: LateBound<any AuthGateway>
        let keyDirectory: any KeyDirectoryGateway
        let identityKeyStore: any IdentityKeyStore
        let tokenProvider: AuthTokenProviderAdapter
        /// The adapter wrapped so concurrent 401s share one refresh; hand this to `APIClient` and
        /// `WebSocketClient`, never the bare adapter.
        let networkTokenProvider: any AuthTokenProvider
        let realtimeLifecycle: any RealtimeLifecycle
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

        let authGateway: any AuthGateway = NotWiredAuthGateway()
        let keyDirectory: any KeyDirectoryGateway = NotWiredKeyDirectoryGateway()
        let identityKeyStore: any IdentityKeyStore = NotWiredIdentityKeyStore()
        authGatewayBinding.bind(authGateway)

        let host = apiConfiguration.baseURL.host() ?? "?"
        let secure = apiConfiguration.isTransportSecure
        AppLog.container.info("production ports built for \(host, privacy: .public) secure=\(secure, privacy: .public)")
        return Ports(
            apiConfiguration: apiConfiguration,
            sessionStore: sessionStore,
            authGateway: authGateway,
            authGatewayBinding: authGatewayBinding,
            keyDirectory: keyDirectory,
            identityKeyStore: identityKeyStore,
            tokenProvider: tokenProvider,
            networkTokenProvider: networkTokenProvider,
            realtimeLifecycle: NoopRealtimeLifecycle()
        )
    }
}
