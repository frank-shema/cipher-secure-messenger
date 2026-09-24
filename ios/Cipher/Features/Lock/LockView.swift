import CipherCore
import CipherDesign
import SwiftUI

/// Full-screen lock. The same screen, title and pad whether the PIN entered opens the real inbox or the
/// decoy: any difference here would be the tell a duress PIN exists to avoid.
struct LockView: View {
    let lock: AppLockManager

    @State private var errorTrigger = 0
    @State private var now = Date()
    @State private var promptedBiometrics = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lockoutRemaining: TimeInterval {
        lock.lockoutRemaining(now: now)
    }

    private var isLockedOut: Bool {
        lockoutRemaining > 0
    }

    var body: some View {
        ZStack {
            LockScreenView(
                title: String(localized: "lock.title", defaultValue: "Unlock Cipher"),
                biometricAvailable: lock.canUseBiometrics,
                digits: lock.settings.pinLength,
                errorTrigger: errorTrigger,
                onBiometric: { Task { await unlockWithBiometrics() } },
                onPIN: { pin in Task { await submit(pin) } }
            )
            .disabled(isLockedOut)
            .accessibilityHidden(isLockedOut)
            if isLockedOut {
                lockoutCard
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
            }
        }
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isLockedOut)
        .task(id: lock.lockoutUntil) { await tickWhileLockedOut() }
        .task { await promptBiometricsOnce() }
        .accessibilityElement(children: .contain)
    }

    private var lockoutCard: some View {
        VStack(spacing: CipherSpacing.md) {
            Image(systemName: "hourglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(CipherColor.warning)
                .accessibilityHidden(true)
            Text(String(localized: "lock.lockout.title", defaultValue: "Too many attempts"))
                .font(CipherTypography.headline)
                .foregroundStyle(CipherColor.textPrimary)
            Text(String(localized: "lock.lockout.message", defaultValue: "Try again in") + " "
                 + CountdownRing.label(forRemaining: lockoutRemaining))
                .font(CipherTypography.mono)
                .foregroundStyle(CipherColor.textSecondary)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(CipherSpacing.xl)
        .background(CipherColor.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
        .cipherShadow(.medium)
        .accessibilityElement(children: .combine)
    }

    private func submit(_ pin: String) async {
        guard await lock.unlock(with: pin) == nil else { return }
        errorTrigger += 1
        now = Date()
    }

    private func unlockWithBiometrics() async {
        _ = await lock.unlockWithBiometrics()
    }

    /// One automatic prompt per lock; the button stays for a retry so a failed scan is never a dead end.
    private func promptBiometricsOnce() async {
        guard !promptedBiometrics, lock.canUseBiometrics, !isLockedOut else { return }
        promptedBiometrics = true
        await unlockWithBiometrics()
    }

    private func tickWhileLockedOut() async {
        now = Date()
        guard let until = lock.lockoutUntil else { return }
        while !Task.isCancelled, Date() < until {
            try? await Task.sleep(for: .seconds(1))
            now = Date()
        }
    }
}

#Preview("Locked") {
    LockView(lock: .preview())
}

#Preview("Locked out") {
    LockView(lock: .preview(biometrics: false, lockedOut: true))
}
