import CipherDesign
import SwiftUI

/// The Settings security block: the App lock row (hidden while the decoy inbox shows, so nothing on
/// screen reveals a lock exists) and the sensitive-content guard's switch.
struct SettingsSecuritySection: View {
    let showsAppLock: Bool
    let onOpenAppLock: () -> Void

    @Environment(AppContainer.self) private var container

    var body: some View {
        if showsAppLock {
            SectionCard(title: String(localized: "settings.section.security", defaultValue: "Security")) {
                Button(action: onOpenAppLock) {
                    SettingsRow(
                        icon: "faceid",
                        title: String(localized: "settings.appLock.title", defaultValue: "App lock"),
                        detail: String(localized: "settings.appLock.detail", defaultValue: "PIN and Face ID")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "settings.appLock.hint", defaultValue: "Opens app lock settings"))
            }
        }
        SensitiveGuardSettingsSection(preferences: SensitiveGuardPreferences(defaults: container.defaults))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: CipherSpacing.xl) {
            SettingsSecuritySection(showsAppLock: true) {}
        }
        .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
