import CipherCore
import CipherDesign
import Foundation
import Observation
import SwiftUI

enum AppLockError: Error, LocalizedError, Hashable, Sendable {
    case invalidPIN(PINError)
    case lengthMismatch
    case decoyMatchesReal
    case noPIN
    case storage(PINVaultError)

    var errorDescription: String? {
        switch self {
        case .invalidPIN(let error): error.errorDescription
        case .lengthMismatch:
            String(localized: "error.lock.lengthMismatch", defaultValue: "The duress PIN must have the same number of digits as your PIN.")
        case .decoyMatchesReal:
            String(localized: "error.lock.decoyMatchesReal", defaultValue: "The duress PIN must be different from your real PIN.")
        case .noPIN:
            String(localized: "error.lock.noPIN", defaultValue: "Set a PIN before adding a duress PIN.")
        case .storage(let error): error.errorDescription
        }
    }
}

/// Owns the locked/unlocked state, the lock preferences and the PINs behind them.
///
/// `mode` is the one output the rest of the app must honour: after a duress unlock it reads `.decoy`
/// and the inbox must come from `DecoyInboxProvider`, never from persistence. Biometrics deliberately
/// never change `mode`: if the last unlock was under duress, a coerced Face ID scan keeps showing the
/// decoy, and only the real PIN brings the real inbox back.
@MainActor
@Observable
final class AppLockManager {
    private(set) var settings: AppLockSettings
    private(set) var isLocked: Bool
    private(set) var mode: AppLockMode = .real
    private(set) var hasPIN: Bool
    private(set) var hasDuressPIN: Bool
    private(set) var failedAttempts: Int
    private(set) var lockoutUntil: Date?
    let biometry: BiometricCapability

    @ObservationIgnored private let vault: any PINVault
    @ObservationIgnored private let store: AppLockSettingsStore
    @ObservationIgnored private let biometrics: any BiometricAuthenticating
    @ObservationIgnored private let haptics: any HapticEngine
    @ObservationIgnored private let clock: any Clock
    @ObservationIgnored private var backgroundedAt: Date?

    init(
        vault: any PINVault,
        settingsStore: AppLockSettingsStore,
        biometrics: any BiometricAuthenticating,
        haptics: any HapticEngine,
        clock: any Clock = SystemClock()
    ) {
        self.vault = vault
        self.store = settingsStore
        self.biometrics = biometrics
        self.haptics = haptics
        self.clock = clock
        let settings = settingsStore.load()
        self.settings = settings
        self.biometry = biometrics.capability()
        self.hasPIN = vault.hasPIN(.real)
        self.hasDuressPIN = vault.hasPIN(.decoy)
        self.failedAttempts = settingsStore.failedAttempts
        self.isLocked = settings.isEnabled && vault.hasPIN(.real)
        self.lockoutUntil = Self.lockoutEnd(
            failures: settingsStore.failedAttempts,
            lastFailureAt: settingsStore.lastFailureAt,
            now: clock.now()
        )
    }

    /// Production wiring: Keychain PINs, `LocalAuthentication`, standard defaults.
    static func live(haptics: any HapticEngine, defaults: UserDefaults = .standard) -> AppLockManager {
        AppLockManager(
            vault: KeychainPINVault(),
            settingsStore: AppLockSettingsStore(defaults: defaults),
            biometrics: BiometricAuthenticator(),
            haptics: haptics
        )
    }

    /// True when a lock can actually engage: switched on and a PIN exists to open it.
    var isConfigured: Bool {
        settings.isEnabled && hasPIN
    }

    var canUseBiometrics: Bool {
        isConfigured && settings.biometricsEnabled && biometry.isAvailable
    }

    var isLockedOut: Bool {
        lockoutRemaining(now: clock.now()) > 0
    }

    func lockoutRemaining(now: Date) -> TimeInterval {
        guard let lockoutUntil else { return 0 }
        return max(0, lockoutUntil.timeIntervalSince(now))
    }

    // MARK: Locking

    func lock() {
        guard isConfigured, !isLocked else { return }
        isLocked = true
        haptics.play(.lock)
        LockLog.lock.info("locked")
    }

    /// Returns which inbox the PIN opened, or nil for a wrong PIN, an absent decoy or an active lockout;
    /// the caller cannot tell those apart, and neither can anyone watching the screen.
    func unlock(with pin: String) async -> AppLockMode? {
        let now = clock.now()
        guard lockoutRemaining(now: now) == 0 else { return nil }
        guard let opened = await vault.verify(pin) else {
            registerFailure(at: now)
            return nil
        }
        clearFailures()
        mode = opened
        isLocked = false
        LockLog.lock.info("unlocked via pin")
        return opened
    }

    /// Biometric unlock keeps whatever `mode` the last PIN chose; see the type documentation for why.
    func unlockWithBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        let reason = String(localized: "lock.biometric.reason", defaultValue: "Unlock Cipher")
        let outcome = await biometrics.authenticate(reason: reason)
        guard outcome == .success else {
            LockLog.lock.debug("biometric unlock declined \(String(describing: outcome), privacy: .public)")
            return false
        }
        clearFailures()
        isLocked = false
        LockLog.lock.info("unlocked via biometrics")
        return true
    }

    /// Locks after the configured grace period in the background. Inactive is ignored: a notification
    /// banner or Control Centre pull should not demand a PIN.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = clock.now()
            if settings.lockAfter == .immediately { lock() }
        case .active:
            if let backgroundedAt, clock.now().timeIntervalSince(backgroundedAt) >= settings.lockAfter.rawValue {
                lock()
            }
            backgroundedAt = nil
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: Settings

    func setLockAfter(_ delay: AutoLockDelay) {
        settings.lockAfter = delay
        store.save(settings)
    }

    func setBiometricsEnabled(_ enabled: Bool) {
        settings.biometricsEnabled = enabled && biometry.isAvailable
        store.save(settings)
    }

    /// Confirms the current real PIN for a settings change. Subject to the same attempt policy as the
    /// lock screen so settings cannot be used as a cheaper place to guess.
    func confirm(_ pin: String) async -> Bool {
        let now = clock.now()
        guard lockoutRemaining(now: now) == 0 else { return false }
        guard await vault.matches(pin, kind: .real) else {
            registerFailure(at: now)
            return false
        }
        clearFailures()
        return true
    }

    /// Sets (or replaces) the real PIN and switches the lock on. Returns true when the duress PIN had to
    /// be dropped because it now collides with the new PIN or no longer matches its length.
    @discardableResult
    func setPIN(_ pin: String, length: PINLength) async throws(AppLockError) -> Bool {
        do {
            try PINRules.validate(pin)
        } catch {
            throw AppLockError.invalidPIN(error)
        }
        guard pin.count == length.rawValue else { throw AppLockError.lengthMismatch }
        var droppedDuress = false
        if hasDuressPIN {
            let collidesWithDecoy = await vault.matches(pin, kind: .decoy)
            if length != settings.pinLength || collidesWithDecoy {
                try removeDuressPIN()
                droppedDuress = true
            }
        }
        do {
            try await vault.store(pin, kind: .real)
        } catch {
            throw AppLockError.storage(error)
        }
        settings.isEnabled = true
        settings.pinLength = length
        store.save(settings)
        hasPIN = true
        LockLog.lock.info("pin set length=\(length.rawValue, privacy: .public)")
        return droppedDuress
    }

    func setDuressPIN(_ pin: String) async throws(AppLockError) {
        guard hasPIN else { throw AppLockError.noPIN }
        do {
            try PINRules.validate(pin)
        } catch {
            throw AppLockError.invalidPIN(error)
        }
        guard pin.count == settings.pinLength.rawValue else { throw AppLockError.lengthMismatch }
        let collidesWithReal = await vault.matches(pin, kind: .real)
        guard !collidesWithReal else { throw AppLockError.decoyMatchesReal }
        do {
            try await vault.store(pin, kind: .decoy)
        } catch {
            throw AppLockError.storage(error)
        }
        hasDuressPIN = true
        LockLog.lock.info("duress pin set")
    }

    func removeDuressPIN() throws(AppLockError) {
        do {
            try vault.remove(.decoy)
        } catch {
            throw AppLockError.storage(error)
        }
        hasDuressPIN = false
        LockLog.lock.info("duress pin removed")
    }

    /// Removes both PINs and turns the lock off. Callers confirm the current PIN first.
    func disableLock() throws(AppLockError) {
        do {
            try vault.remove(.decoy)
            try vault.remove(.real)
        } catch {
            throw AppLockError.storage(error)
        }
        hasPIN = false
        hasDuressPIN = false
        settings.isEnabled = false
        settings.biometricsEnabled = false
        store.save(settings)
        isLocked = false
        mode = .real
        clearFailures()
        LockLog.lock.info("lock disabled")
    }

    // MARK: Attempts

    private func registerFailure(at now: Date) {
        store.recordFailure(at: now)
        failedAttempts = store.failedAttempts
        lockoutUntil = Self.lockoutEnd(failures: failedAttempts, lastFailureAt: now, now: now)
        haptics.play(.warning)
        LockLog.lock.notice("pin rejected attempts=\(self.failedAttempts, privacy: .public)")
    }

    private func clearFailures() {
        store.resetFailures()
        failedAttempts = 0
        lockoutUntil = nil
    }

    private static func lockoutEnd(failures: Int, lastFailureAt: Date?, now: Date) -> Date? {
        guard let lastFailureAt else { return nil }
        let wait = PINAttemptPolicy.lockout(afterFailedAttempts: failures)
        guard wait > 0 else { return nil }
        let end = lastFailureAt.addingTimeInterval(wait)
        return end > now ? end : nil
    }
}

// MARK: - Previews

extension AppLockManager {
    /// Fully in-memory manager for previews. PIN "123456", duress PIN "654321" unless overridden.
    static func preview(
        enabled: Bool = true,
        locked: Bool = true,
        biometrics: Bool = true,
        lockedOut: Bool = false,
        pin: String = "123456",
        duressPIN: String? = "654321"
    ) -> AppLockManager {
        let defaults = UserDefaults(suiteName: "com.cipher.preview.lock.\(UUID().uuidString)") ?? .standard
        let store = AppLockSettingsStore(defaults: defaults)
        var settings = AppLockSettings()
        settings.isEnabled = enabled
        settings.biometricsEnabled = biometrics
        store.save(settings)
        if lockedOut {
            for _ in 0...PINAttemptPolicy.freeAttempts { store.recordFailure(at: Date()) }
        }
        let manager = AppLockManager(
            vault: InMemoryPINVault(real: enabled ? pin : nil, decoy: enabled ? duressPIN : nil),
            settingsStore: store,
            biometrics: PreviewBiometricAuthenticator(stubCapability: BiometricCapability(kind: .faceID, isAvailable: biometrics)),
            haptics: NoopHapticEngine()
        )
        manager.isLocked = locked && manager.isConfigured
        return manager
    }
}
