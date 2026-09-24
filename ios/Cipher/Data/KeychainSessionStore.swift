import CipherCore
import Foundation

/// Persists the relay session (user + access/refresh tokens) in the Keychain.
///
/// Tokens are the one secret the app holds besides identity keys, so they never touch UserDefaults or a
/// plist. The whole `Session` is stored as one JSON blob: the pieces are only ever read together, and a
/// single item means a torn write cannot leave an access token paired with a stale refresh token.
///
/// An actor keeps the synchronous Security calls off the main thread and serialises writes.
actor KeychainSessionStore: SessionStore {
    static let defaultService = "com.cipher.session"
    private static let account = "current"

    private let store: KeychainStore
    private let encoder = WireJSON.makeEncoder()
    private let decoder = WireJSON.makeDecoder()

    init(service: String = KeychainSessionStore.defaultService) {
        self.store = KeychainStore(service: service)
    }

    func load() async throws -> Session? {
        guard let data = try store.read(account: Self.account) else {
            AppLog.keychain.debug("no stored session")
            return nil
        }
        do {
            let session = try decoder.decode(Session.self, from: data)
            AppLog.keychain.info("restored session for \(session.user.id.description, privacy: .public)")
            return session
        } catch {
            // A session that cannot be decoded (schema change, corruption) is unusable; clearing it forces a
            // clean sign-in rather than looping on the same decode failure at every launch.
            AppLog.keychain.error("stored session undecodable; clearing")
            try store.delete(account: Self.account)
            return nil
        }
    }

    func save(_ session: Session) async throws {
        let data = try encoder.encode(session)
        try store.write(data, account: Self.account)
        AppLog.keychain.info("saved session for \(session.user.id.description, privacy: .public)")
    }

    func clear() async throws {
        try store.delete(account: Self.account)
        AppLog.keychain.info("cleared session")
    }
}
