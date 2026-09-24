import CipherCore
import Foundation
import Security

/// Persists the relay session (user + access/refresh tokens) in the Keychain.
///
/// Tokens are the one secret the app holds besides identity keys, so they never touch UserDefaults or a
/// plist. The whole `Session` is stored as one JSON blob: the pieces are only ever read together, and a
/// single item means a torn write cannot leave an access token paired with a stale refresh token.
///
/// The item is readable after the first unlock, not only while unlocked: a session restore runs at
/// launch, which after a reboot can happen before the data-protection keychain considers the device
/// unlocked, and losing the session there would send the person back to Welcome for no reason.
///
/// An actor keeps the synchronous Security calls off the main thread and serialises writes.
actor KeychainSessionStore: SessionStore {
    static let defaultService = "com.cipher.session"
    private static let account = "current"
    /// How long to wait before the one retry when the keychain is not yet readable after boot.
    private static let interactionRetryDelay: Duration = .milliseconds(600)

    private let store: KeychainStore
    private let encoder = WireJSON.makeEncoder()
    private let decoder = WireJSON.makeDecoder()

    init(service: String = KeychainSessionStore.defaultService) {
        self.store = KeychainStore(service: service, accessibility: .afterFirstUnlock)
    }

    func load() async throws -> Session? {
        guard let data = try await readSessionData() else {
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

    /// `errSecInteractionNotAllowed` means the keychain is momentarily locked (right after boot, before
    /// the first unlock has propagated), not that the session is gone. One short retry covers that
    /// window; a second failure is reported so the caller can decide, rather than silently signing out.
    private func readSessionData() async throws -> Data? {
        do {
            return try store.read(account: Self.account)
        } catch KeychainError.unexpectedStatus(errSecInteractionNotAllowed) {
            AppLog.keychain.notice("keychain not yet readable; retrying session read once")
            try await Task.sleep(for: Self.interactionRetryDelay)
            return try store.read(account: Self.account)
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
