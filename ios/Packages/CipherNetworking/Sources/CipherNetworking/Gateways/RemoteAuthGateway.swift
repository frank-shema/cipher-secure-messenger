import CipherCore
import Foundation

/// `AuthGateway` over the relay's `/auth/*` routes. Session expiry is computed from the clock read
/// *before* the request leaves, so network latency can only make the client refresh early, never late.
public struct RemoteAuthGateway: AuthGateway {
    private let client: APIClient
    private let clock: any Clock

    public init(client: APIClient, clock: any Clock = SystemClock()) {
        self.client = client
        self.clock = clock
    }

    public func register(username: String, password: String, displayName: String?) async throws -> Session {
        let issuedAt = clock.now()
        let request = RegisterRequest(username: username, password: password, displayName: displayName)
        let response = try await client.send(RegisterEndpoint(request))
        NetLog.api.info("registered user \(response.user.id.description, privacy: .public)")
        return response.toDomain(issuedAt: issuedAt)
    }

    public func login(username: String, password: String) async throws -> Session {
        let issuedAt = clock.now()
        let response = try await client.send(LoginEndpoint(LoginRequest(username: username, password: password)))
        NetLog.api.info("signed in user \(response.user.id.description, privacy: .public)")
        return response.toDomain(issuedAt: issuedAt)
    }

    public func refresh(refreshToken: String) async throws -> Session {
        let issuedAt = clock.now()
        let response = try await client.send(RefreshEndpoint(RefreshTokenRequest(refreshToken: refreshToken)))
        return response.toDomain(issuedAt: issuedAt)
    }

    /// Idempotent on the relay; a token that is already revoked still yields 204.
    public func logout(refreshToken: String) async throws {
        _ = try await client.send(LogoutEndpoint(RefreshTokenRequest(refreshToken: refreshToken)))
        NetLog.api.info("signed out")
    }
}
