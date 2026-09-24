import CipherCore
import Foundation

/// Non-secret, per-device preferences. Anything secret (tokens, keys) lives in the Keychain instead.
/// Keys are namespaced so a future migration can find every Cipher default by prefix.
enum AppPreferences {
    enum Key {
        static let serverURLOverride = "cipher.settings.serverURLOverride"
        static let demoCompanionEnabled = "cipher.debug.demoCompanionEnabled"
        static let publishedIdentityUserIds = "cipher.identity.publishedUserIds"
    }

    static func serverURLOverride(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: Key.serverURLOverride)
    }

    /// Stores a trimmed override, or removes it when the text is blank so the default relay applies again.
    static func setServerURLOverride(_ raw: String?, in defaults: UserDefaults = .standard) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Key.serverURLOverride)
        } else {
            defaults.set(trimmed, forKey: Key.serverURLOverride)
        }
    }

    static func endpoints(in defaults: UserDefaults = .standard) -> ServerEndpoints {
        ServerEndpoints.resolve(override: serverURLOverride(in: defaults))
    }

    static func isDemoCompanionEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.demoCompanionEnabled)
    }

    static func setDemoCompanionEnabled(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: Key.demoCompanionEnabled)
    }
}

/// Remembers which accounts have successfully published their identity keys on this device.
///
/// The relay is the source of truth, but asking it at every launch would make a cold start depend on
/// the network. Recording success locally lets a returning person land straight in the app; a fresh
/// account (or a cleared record after rotation trouble) goes through the key-generation screen again,
/// where `PUT /keys/me` is idempotent for identical keys anyway.
///
/// `UserDefaults` is documented as thread-safe but is not marked `Sendable` by the SDK, hence the
/// unchecked conformance; the registry holds nothing else.
struct IdentityPublicationRegistry: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasPublished(_ userId: UserID) -> Bool {
        published().contains(userId.description)
    }

    func markPublished(_ userId: UserID) {
        var ids = published()
        ids.insert(userId.description)
        defaults.set(Array(ids).sorted(), forKey: AppPreferences.Key.publishedIdentityUserIds)
    }

    func clear(_ userId: UserID) {
        var ids = published()
        ids.remove(userId.description)
        defaults.set(Array(ids).sorted(), forKey: AppPreferences.Key.publishedIdentityUserIds)
    }

    private func published() -> Set<String> {
        Set(defaults.stringArray(forKey: AppPreferences.Key.publishedIdentityUserIds) ?? [])
    }
}
