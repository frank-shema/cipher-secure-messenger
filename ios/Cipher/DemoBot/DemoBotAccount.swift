#if DEBUG
import CipherCore
import CipherNetworking
import Foundation

/// Signs the companion in, registering it the first time a relay sees it, and renews its session.
struct DemoBotAccount: Sendable {
    private let credentials: DemoBotCredentials
    private let auth: any AuthGateway

    init(credentials: DemoBotCredentials, auth: any AuthGateway) {
        self.credentials = credentials
        self.auth = auth
    }

    /// Login first, because the account usually exists. A 401 means it does not (a fresh relay, or one
    /// whose database was reset), so the bot registers itself. Anything else is surfaced: in particular
    /// a 409 on register means somebody else owns `echo` on this relay and the demo cannot run.
    func signIn() async throws -> Session {
        do {
            let session = try await auth.login(username: credentials.username, password: credentials.password)
            DemoBotLog.account.info("signed in as \(session.user.id.description, privacy: .public)")
            return session
        } catch let error as APIError {
            guard case .unauthorized = error else { throw DemoBotError.signInFailed(status: error.statusCode) }
            DemoBotLog.account.info("no companion account on this relay; registering")
        }
        return try await register()
    }

    func refresh(_ session: Session) async throws -> Session {
        try await auth.refresh(refreshToken: session.refreshToken)
    }

    private func register() async throws -> Session {
        do {
            let session = try await auth.register(
                username: credentials.username,
                password: credentials.password,
                displayName: credentials.displayName
            )
            DemoBotLog.account.info("registered as \(session.user.id.description, privacy: .public)")
            return session
        } catch let error as APIError {
            if error.problem?.kind == .usernameTaken || error.statusCode == 409 {
                throw DemoBotError.accountTaken
            }
            throw DemoBotError.signInFailed(status: error.statusCode)
        }
    }
}

/// The companion's `AuthTokenProvider`. Its session lives in memory only (the Keychain session slot
/// belongs to the person), is refreshed before it expires, and is simply re-created from the fixed
/// credentials when the relay rejects the refresh token, so the bot can never be "signed out" for
/// good. An actor so concurrent callers always see one consistent session.
actor DemoBotTokenProvider: AuthTokenProvider {
    private var session: Session
    private let account: DemoBotAccount
    private let clock: any Clock

    init(session: Session, account: DemoBotAccount, clock: any Clock = SystemClock()) {
        self.session = session
        self.account = account
        self.clock = clock
    }

    var current: Session {
        session
    }

    func accessToken() async throws -> String? {
        guard session.isAccessTokenExpired(at: clock.now()) else { return session.accessToken }
        return try await refresh()
    }

    func refresh() async throws -> String {
        do {
            session = try await account.refresh(session)
            DemoBotLog.account.info("refreshed companion session")
        } catch where !FailureClassifier.isTransient(error) {
            let name = String(describing: type(of: error))
            DemoBotLog.account.notice("refresh rejected (\(name, privacy: .public)); signing in again")
            session = try await account.signIn()
        }
        return session.accessToken
    }
}
#endif
