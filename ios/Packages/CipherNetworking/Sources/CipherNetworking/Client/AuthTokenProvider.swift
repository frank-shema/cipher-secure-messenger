import Foundation

/// Bridges the app's session store to the transport layer. The client never sees a refresh token: it
/// asks for the current access token and, on a 401 or a 4001 socket close, asks for a renewed one.
public protocol AuthTokenProvider: Sendable {
    /// The current access token, or nil when nobody is signed in. May throw when supplying a token
    /// requires a proactive refresh that fails (for example, offline with an expired token).
    func accessToken() async throws -> String?
    /// Exchanges the refresh token for a new session and returns the new access token. Throws when the
    /// session cannot be renewed (revoked, expired, offline); the caller then treats the user as signed out.
    func refresh() async throws -> String
}

/// Dedupes concurrent refreshes. Refresh tokens rotate on every use (PROTOCOL.md §1.1), so two requests
/// hitting 401 at the same moment must share one refresh call: the second would otherwise present an
/// already-used token and log the person out. Wrap the app's provider in this once and share it between
/// `APIClient` and `WebSocketClient`.
public actor CoalescingAuthTokenProvider: AuthTokenProvider {
    private let base: any AuthTokenProvider
    private var inFlight: Task<String, any Error>?

    public init(_ base: any AuthTokenProvider) {
        self.base = base
    }

    public func accessToken() async throws -> String? {
        try await base.accessToken()
    }

    public func refresh() async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task<String, any Error> { [base] in
            try await base.refresh()
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

/// A provider with a fixed token and no refresh path. Handy for previews, tools and the DEBUG demo bot,
/// which mints its own session and never needs rotation.
public struct StaticAuthTokenProvider: AuthTokenProvider {
    private let token: String?

    public init(token: String?) {
        self.token = token
    }

    public func accessToken() async throws -> String? {
        token
    }

    public func refresh() async throws -> String {
        guard let token else { throw APIError.unauthorized(nil) }
        return token
    }
}
