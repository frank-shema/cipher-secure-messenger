import CipherCore
import Foundation

/// Failures of token supply, distinct from transport errors so callers can tell "nobody is signed in"
/// from "the refresh call failed" and react differently (sign out vs. retry later).
enum AuthTokenError: Error, LocalizedError, Hashable, Sendable {
    case noSession
    case authGatewayUnavailable
    case refreshRejected

    var errorDescription: String? {
        switch self {
        case .noSession:
            String(localized: "error.token.noSession", defaultValue: "You are signed out.")
        case .authGatewayUnavailable:
            String(localized: "error.token.gatewayUnavailable", defaultValue: "Sign-in is not available in this build.")
        case .refreshRejected:
            String(localized: "error.token.refreshRejected", defaultValue: "Your session has expired. Please sign in again.")
        }
    }
}

/// Bridges the persisted `Session` to the networking layer's token needs.
///
/// The API client asks for a Bearer token before each request and asks for a refresh after a 401. Both
/// funnel through here so that (1) a refresh is single-flight: ten concurrent 401s produce one
/// `/auth/refresh` call, which matters because refresh tokens rotate and a second use of the old one is
/// rejected; (2) every new session is written back to the Keychain before any caller sees the token;
/// (3) a rejected refresh is reported exactly once so the app can sign the person out.
///
/// The method shapes match `CipherNetworking.AuthTokenProvider`; the conformance itself lives in
/// `NetworkingBridges.swift` so this file stays free of the networking module.
actor AuthTokenProviderAdapter {
    private let sessionStore: any SessionStore
    private let authGateway: LateBound<any AuthGateway>
    private let clock: any Clock
    private let onSessionRefreshed: @Sendable (Session) -> Void
    private let onRefreshRejected: @Sendable () -> Void
    private var inFlightRefresh: Task<String, any Error>?

    init(
        sessionStore: any SessionStore,
        authGateway: LateBound<any AuthGateway>,
        clock: any Clock = SystemClock(),
        onSessionRefreshed: @escaping @Sendable (Session) -> Void,
        onRefreshRejected: @escaping @Sendable () -> Void
    ) {
        self.sessionStore = sessionStore
        self.authGateway = authGateway
        self.clock = clock
        self.onSessionRefreshed = onSessionRefreshed
        self.onRefreshRejected = onRefreshRejected
    }

    /// The current access token, refreshed proactively when it is about to expire so requests do not
    /// pay for a 401 round trip. Nil when nobody is signed in (public endpoints) or when a refresh
    /// failed; the request then proceeds unauthenticated and the relay's 401 drives the retry path.
    func accessToken() async -> String? {
        do {
            guard let session = try await sessionStore.load() else { return nil }
            guard session.isAccessTokenExpired(at: clock.now()) else { return session.accessToken }
            return try await refresh()
        } catch {
            AppLog.session.notice("access token unavailable: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    /// Exchanges the refresh token for a new session and returns the new access token.
    func refresh() async throws -> String {
        if let inFlightRefresh {
            return try await inFlightRefresh.value
        }
        let task = Task<String, any Error> { [sessionStore, authGateway, onSessionRefreshed, onRefreshRejected] in
            guard let current = try await sessionStore.load() else { throw AuthTokenError.noSession }
            guard let gateway = authGateway.value else { throw AuthTokenError.authGatewayUnavailable }
            do {
                let renewed = try await gateway.refresh(refreshToken: current.refreshToken)
                try await sessionStore.save(renewed)
                onSessionRefreshed(renewed)
                AppLog.session.info("refreshed session for \(renewed.user.id.description, privacy: .public)")
                return renewed.accessToken
            } catch where !FailureClassifier.isTransient(error) {
                // A permanent rejection means the refresh token is revoked or expired: the session is dead
                // and keeping it would only produce the same 401 on every request.
                AppLog.session.notice("refresh rejected: \(String(describing: type(of: error)), privacy: .public)")
                try await sessionStore.clear()
                onRefreshRejected()
                throw AuthTokenError.refreshRejected
            }
        }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }
        return try await task.value
    }
}
