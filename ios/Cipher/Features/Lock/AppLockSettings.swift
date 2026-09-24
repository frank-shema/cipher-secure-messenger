import CipherDesign
import Foundation

/// How long the app may sit in the background before it locks again. Short enough that handing the
/// phone over for a photo does not hand over the inbox; long enough that switching to Maps and back
/// does not demand a PIN every time.
enum AutoLockDelay: TimeInterval, CaseIterable, Identifiable, Sendable {
    case immediately = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: TimeInterval { rawValue }

    var title: String {
        switch self {
        case .immediately: String(localized: "lock.autoLock.immediately", defaultValue: "Immediately")
        case .thirtySeconds: String(localized: "lock.autoLock.thirtySeconds", defaultValue: "After 30 seconds")
        case .oneMinute: String(localized: "lock.autoLock.oneMinute", defaultValue: "After 1 minute")
        case .fiveMinutes: String(localized: "lock.autoLock.fiveMinutes", defaultValue: "After 5 minutes")
        case .fifteenMinutes: String(localized: "lock.autoLock.fifteenMinutes", defaultValue: "After 15 minutes")
        }
    }
}

/// Non-secret lock preferences. The PINs themselves never live here; see `PINVault`.
struct AppLockSettings: Hashable, Sendable {
    var isEnabled = false
    var biometricsEnabled = false
    var lockAfter: AutoLockDelay = .oneMinute
    /// Both PINs share one length because the pad submits automatically on the last digit.
    var pinLength: PINLength = .six
}

/// `UserDefaults` persistence for `AppLockSettings` and the failed-attempt counter. Failures are
/// persisted so relaunching the app does not reset the lockout clock. `UserDefaults` is documented as
/// thread-safe but not marked `Sendable`, hence the unchecked conformance.
struct AppLockSettingsStore: @unchecked Sendable {
    enum Key {
        static let enabled = "cipher.lock.enabled"
        static let biometrics = "cipher.lock.biometrics"
        static let lockAfterSeconds = "cipher.lock.lockAfterSeconds"
        static let pinLength = "cipher.lock.pinLength"
        static let failedAttempts = "cipher.lock.failedAttempts"
        static let lastFailureAt = "cipher.lock.lastFailureAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppLockSettings {
        var settings = AppLockSettings()
        settings.isEnabled = defaults.bool(forKey: Key.enabled)
        settings.biometricsEnabled = defaults.bool(forKey: Key.biometrics)
        if defaults.object(forKey: Key.lockAfterSeconds) != nil,
           let delay = AutoLockDelay(rawValue: defaults.double(forKey: Key.lockAfterSeconds)) {
            settings.lockAfter = delay
        }
        if let length = PINLength(rawValue: defaults.integer(forKey: Key.pinLength)) {
            settings.pinLength = length
        }
        return settings
    }

    func save(_ settings: AppLockSettings) {
        defaults.set(settings.isEnabled, forKey: Key.enabled)
        defaults.set(settings.biometricsEnabled, forKey: Key.biometrics)
        defaults.set(settings.lockAfter.rawValue, forKey: Key.lockAfterSeconds)
        defaults.set(settings.pinLength.rawValue, forKey: Key.pinLength)
    }

    var failedAttempts: Int {
        defaults.integer(forKey: Key.failedAttempts)
    }

    var lastFailureAt: Date? {
        defaults.object(forKey: Key.lastFailureAt) as? Date
    }

    func recordFailure(at date: Date) {
        defaults.set(failedAttempts + 1, forKey: Key.failedAttempts)
        defaults.set(date, forKey: Key.lastFailureAt)
    }

    func resetFailures() {
        defaults.removeObject(forKey: Key.failedAttempts)
        defaults.removeObject(forKey: Key.lastFailureAt)
    }
}
