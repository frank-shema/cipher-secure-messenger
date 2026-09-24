import CipherCore
import Foundation

/// In-memory `/auth/*`. Accounts registered through it can log in again within the same process, so a
/// preview or UI test can exercise the whole onboarding path without a relay.
actor MockAuthGateway: AuthGateway {
    /// Mirrors the relay's problem types for the auth routes (PROTOCOL.md §1.1, §5).
    enum Failure: ProblemPresentable, LocalizedError, Hashable {
        case invalidCredentials
        case usernameTaken
        case invalidRefreshToken
        case offline

        var problemType: String? {
            switch self {
            case .invalidCredentials: "urn:cipher:problem:invalid-credentials"
            case .usernameTaken: "urn:cipher:problem:username-taken"
            case .invalidRefreshToken: "urn:cipher:problem:invalid-refresh-token"
            case .offline: nil
            }
        }

        var problemStatus: Int? {
            switch self {
            case .invalidCredentials, .invalidRefreshToken: 401
            case .usernameTaken: 409
            case .offline: nil
            }
        }

        var problemTitle: String? {
            switch self {
            case .invalidCredentials: String(localized: "mock.auth.invalidCredentials.title", defaultValue: "Invalid credentials")
            case .usernameTaken: String(localized: "mock.auth.usernameTaken.title", defaultValue: "Username taken")
            case .invalidRefreshToken: String(localized: "mock.auth.invalidRefresh.title", defaultValue: "Session expired")
            case .offline: String(localized: "mock.auth.offline.title", defaultValue: "You are offline")
            }
        }

        var problemDetail: String? {
            switch self {
            case .invalidCredentials:
                String(localized: "mock.auth.invalidCredentials.detail", defaultValue: "The username or password is incorrect.")
            case .usernameTaken:
                String(localized: "mock.auth.usernameTaken.detail", defaultValue: "Someone already registered this username.")
            case .invalidRefreshToken:
                String(localized: "mock.auth.invalidRefresh.detail", defaultValue: "Please sign in again.")
            case .offline:
                String(localized: "mock.auth.offline.detail", defaultValue: "Check your connection and try again.")
            }
        }

        var correlationId: String? { "preview-correlation" }
        var errorDescription: String? { problemDetail }
    }

    private struct Account {
        var user: User
        var password: String
    }

    private var accounts: [String: Account]
    private var refreshTokens: Set<String> = []
    private var nextFailure: Failure?
    private let latency: Duration
    private let clock: any Clock

    /// - Parameters:
    ///   - seeded: Accounts that exist before anything registers; all share `Fixtures.password`.
    ///   - latency: Simulated round trip so loading states are visible in previews.
    init(seeded: [User] = Fixtures.users, latency: Duration = .milliseconds(400), clock: any Clock = SystemClock()) {
        self.accounts = Dictionary(uniqueKeysWithValues: seeded.map { ($0.username, Account(user: $0, password: Fixtures.password)) })
        self.latency = latency
        self.clock = clock
    }

    /// Makes the next call fail once, for previewing error banners.
    func failNext(with failure: Failure) {
        nextFailure = failure
    }

    func register(username: String, password: String, displayName: String?) async throws -> Session {
        try await simulateRoundTrip()
        guard accounts[username] == nil else { throw Failure.usernameTaken }
        let user = User(id: UserID(), username: username, displayName: displayName?.nilIfBlank ?? username)
        accounts[username] = Account(user: user, password: password)
        return issueSession(for: user)
    }

    func login(username: String, password: String) async throws -> Session {
        try await simulateRoundTrip()
        guard let account = accounts[username], account.password == password else { throw Failure.invalidCredentials }
        return issueSession(for: account.user)
    }

    func refresh(refreshToken: String) async throws -> Session {
        try await simulateRoundTrip()
        guard refreshTokens.remove(refreshToken) != nil,
              let username = refreshToken.split(separator: ":").dropFirst().first,
              let account = accounts[String(username)]
        else { throw Failure.invalidRefreshToken }
        return issueSession(for: account.user)
    }

    func logout(refreshToken: String) async throws {
        try await simulateRoundTrip()
        refreshTokens.remove(refreshToken)
    }

    private func issueSession(for user: User) -> Session {
        let refresh = "refresh:\(user.username):\(UUID().uuidString)"
        refreshTokens.insert(refresh)
        return Session(
            user: user,
            accessToken: "access:\(UUID().uuidString)",
            refreshToken: refresh,
            accessTokenExpiresAt: clock.now().addingTimeInterval(900)
        )
    }

    private func simulateRoundTrip() async throws {
        try await Task.sleep(for: latency)
        if let failure = nextFailure {
            nextFailure = nil
            throw failure
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
