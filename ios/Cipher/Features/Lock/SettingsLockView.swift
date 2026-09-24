import CipherDesign
import SwiftUI

/// App lock settings: PIN, biometrics, auto-lock delay, the duress PIN and flip-to-hide. Destination of
/// `Route.lockSettings`. Every PIN change goes through `PINSetupSheet`, which confirms the current PIN
/// first, so this screen never handles a PIN itself.
struct SettingsLockView: View {
    let lock: AppLockManager
    var flipToHide: FlipToHideMonitor?

    @State private var setup: PINSetupIntent?
    @State private var confirmingDuressRemoval = false
    @State private var issue: String?

    var body: some View {
        ScrollView {
            VStack(spacing: CipherSpacing.xl) {
                AppLockSection(
                    lock: lock,
                    onCreatePIN: { setup = .createPIN },
                    onChangePIN: { setup = .changePIN },
                    onDisable: { setup = .disableLock }
                )
                DuressPINSection(
                    lock: lock,
                    onCreate: { setup = .createDuressPIN },
                    onChange: { setup = .changeDuressPIN },
                    onRemove: { confirmingDuressRemoval = true }
                )
                if let flipToHide {
                    PrivacySection(monitor: flipToHide)
                }
            }
            .padding(CipherSpacing.lg)
        }
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(String(localized: "lock.settings.title", defaultValue: "App lock"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $setup) { intent in
            PINSetupSheet(intent: intent, lock: lock)
        }
        .confirmationDialog(
            String(localized: "lock.duress.remove.confirm.title", defaultValue: "Remove the duress PIN?"),
            isPresented: $confirmingDuressRemoval,
            titleVisibility: .visible
        ) {
            Button(String(localized: "lock.duress.remove", defaultValue: "Remove duress PIN"), role: .destructive) {
                removeDuressPIN()
            }
        } message: {
            Text(String(localized: "lock.duress.remove.confirm.message",
                        defaultValue: "Entering it will then simply count as a wrong PIN."))
        }
        .alert(
            String(localized: "lock.settings.error.title", defaultValue: "Could not update the lock"),
            isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } }),
            actions: { Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {} },
            message: { Text(issue ?? "") }
        )
    }

    private func removeDuressPIN() {
        do {
            try lock.removeDuressPIN()
        } catch {
            issue = error.localizedDescription
        }
    }
}

#Preview("Configured") {
    NavigationStack {
        SettingsLockView(lock: .preview(locked: false), flipToHide: FlipToHideMonitor(source: PreviewGravitySource()))
    }
}

#Preview("Off") {
    NavigationStack {
        SettingsLockView(
            lock: .preview(enabled: false, locked: false),
            flipToHide: FlipToHideMonitor(source: PreviewGravitySource(isAvailable: false))
        )
    }
}
