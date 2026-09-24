import Foundation

/// An authenticated relay session. Tokens are secrets: `description` deliberately redacts them so a
/// stray `print` or log interpolation can never leak one.
public struct Session: Hashable, Codable, Sendable, CustomStringConvertible {
    public var user: User
    public var accessToken: String
    public var refreshToken: String
    public var accessTokenExpiresAt: Date

    public init(user: User, accessToken: String, refreshToken: String, accessTokenExpiresAt: Date) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }

    /// Access tokens live 15 minutes; the leeway avoids sending a request that expires in flight.
    public func isAccessTokenExpired(at now: Date, leeway: TimeInterval = 30) -> Bool {
        now.addingTimeInterval(leeway) >= accessTokenExpiresAt
    }

    public var description: String {
        "Session(user: \(user.id), expires: \(accessTokenExpiresAt.epochMillis))"
    }
}

/// `/api/v1/auth/*` (PROTOCOL.md §1.1).
public protocol AuthGateway: Sendable {
    func register(username: String, password: String, displayName: String?) async throws -> Session
    func login(username: String, password: String) async throws -> Session
    /// Rotates the refresh token: the returned session carries a new one and the old is revoked.
    func refresh(refreshToken: String) async throws -> Session
    func logout(refreshToken: String) async throws
}

/// Secure persistence for the current session (Keychain in the app's Data layer).
public protocol SessionStore: Sendable {
    func load() async throws -> Session?
    func save(_ session: Session) async throws
    func clear() async throws
}
