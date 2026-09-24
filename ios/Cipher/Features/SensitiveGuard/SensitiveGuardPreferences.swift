import Foundation

/// The Settings switch for the guard. Stored as "disabled" so a fresh install, where the key is
/// absent, has the guard on: protection that must be opted into protects nobody.
///
/// `UserDefaults` is documented thread-safe but not marked `Sendable` by the SDK, hence the unchecked
/// conformance; the value holds nothing else, and the guard reads it from its own actor.
struct SensitiveGuardPreferences: @unchecked Sendable {
    static let disabledKey = "cipher.settings.sensitiveGuardDisabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { !defaults.bool(forKey: Self.disabledKey) }
        nonmutating set {
            defaults.set(!newValue, forKey: Self.disabledKey)
            SensitiveGuardLog.guardian.info("sensitive-content guard \(newValue ? "enabled" : "disabled", privacy: .public)")
        }
    }

    /// A reader closure for `SensitiveContentGuard(isEnabled:)`, evaluated on every scan.
    var reader: @Sendable () -> Bool {
        let preferences = self
        return { preferences.isEnabled }
    }
}
