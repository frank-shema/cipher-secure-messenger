import CipherDesign
import SwiftUI

/// The Settings card with the guard's on/off switch and the on-device promise. Drop it into
/// `SettingsView` between the security and developer cards.
struct SensitiveGuardSettingsSection: View {
    let preferences: SensitiveGuardPreferences

    @State private var isEnabled: Bool

    init(preferences: SensitiveGuardPreferences) {
        self.preferences = preferences
        _isEnabled = State(initialValue: preferences.isEnabled)
    }

    var body: some View {
        SectionCard(title: String(localized: "sensitiveGuard.settings.section", defaultValue: "Privacy")) {
            Toggle(isOn: $isEnabled) {
                SettingsRow(
                    icon: "eye.trianglebadge.exclamationmark",
                    title: String(localized: "sensitiveGuard.settings.title", defaultValue: "Sensitive-content guard"),
                    detail: String(
                        localized: "sensitiveGuard.settings.detail",
                        defaultValue: "Spots passwords, codes and card numbers as you type"
                    ),
                    showsChevron: false
                )
            }
            .tint(CipherColor.accent)
            .accessibilityLabel(String(localized: "sensitiveGuard.settings.title", defaultValue: "Sensitive-content guard"))
            .onChange(of: isEnabled) { _, enabled in
                preferences.isEnabled = enabled
            }
            Text(String(
                localized: "sensitiveGuard.settings.footer",
                defaultValue: "Analysis runs entirely on this device. A draft is never sent anywhere before you tap send."
            ))
            .font(CipherTypography.caption)
            .foregroundStyle(CipherColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, CipherSpacing.md)
        }
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview.sensitiveGuard") ?? .standard
    ScrollView {
        SensitiveGuardSettingsSection(preferences: SensitiveGuardPreferences(defaults: defaults))
            .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
}
