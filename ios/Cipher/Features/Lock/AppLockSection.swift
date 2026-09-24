import CipherDesign
import SwiftUI

/// The "Require PIN" switch and everything that only makes sense once it is on.
struct AppLockSection: View {
    let lock: AppLockManager
    let onCreatePIN: () -> Void
    let onChangePIN: () -> Void
    let onDisable: () -> Void

    var body: some View {
        SectionCard(title: String(localized: "lock.section.appLock", defaultValue: "App lock")) {
            Toggle(isOn: Binding(get: { lock.isConfigured }, set: { $0 ? onCreatePIN() : onDisable() })) {
                SettingsRow(
                    icon: "lock.fill",
                    title: String(localized: "lock.requirePIN.title", defaultValue: "Require PIN"),
                    detail: String(localized: "lock.requirePIN.detail", defaultValue: "Ask for a PIN when Cipher opens"),
                    showsChevron: false
                )
            }
            .tint(CipherColor.accent)
            if lock.isConfigured {
                divider
                Button(action: onChangePIN) {
                    SettingsRow(
                        icon: "key.fill",
                        title: String(localized: "lock.changePIN.title", defaultValue: "Change PIN"),
                        detail: String(localized: "lock.changePIN.detail", defaultValue: "\(lock.settings.pinLength.rawValue) digits")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "lock.changePIN.hint", defaultValue: "Asks for your current PIN first"))
                if lock.biometry.isAvailable {
                    divider
                    Toggle(isOn: Binding(get: { lock.settings.biometricsEnabled }, set: { lock.setBiometricsEnabled($0) })) {
                        SettingsRow(
                            icon: lock.biometry.kind.systemImage,
                            title: String(localized: "lock.biometrics.title", defaultValue: "Unlock with") + " " + lock.biometry.kind.title,
                            detail: String(localized: "lock.biometrics.detail", defaultValue: "Your PIN still works as a fallback"),
                            showsChevron: false
                        )
                    }
                    .tint(CipherColor.accent)
                }
                divider
                autoLockPicker
            }
        }
    }

    private var autoLockPicker: some View {
        HStack(spacing: CipherSpacing.md) {
            SettingsRow(
                icon: "timer",
                title: String(localized: "lock.autoLock.title", defaultValue: "Auto-lock"),
                detail: String(localized: "lock.autoLock.detail", defaultValue: "When Cipher goes to the background"),
                showsChevron: false
            )
            Picker(
                String(localized: "lock.autoLock.title", defaultValue: "Auto-lock"),
                selection: Binding(get: { lock.settings.lockAfter }, set: { lock.setLockAfter($0) })
            ) {
                ForEach(AutoLockDelay.allCases) { delay in
                    Text(delay.title).tag(delay)
                }
            }
            .pickerStyle(.menu)
            .tint(CipherColor.accent)
            .labelsHidden()
            .accessibilityLabel(String(localized: "lock.autoLock.title", defaultValue: "Auto-lock"))
        }
    }

    private var divider: some View {
        Divider().overlay(CipherColor.divider).padding(.vertical, CipherSpacing.md)
    }
}

#Preview {
    AppLockSection(lock: .preview(locked: false), onCreatePIN: {}, onChangePIN: {}, onDisable: {})
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
