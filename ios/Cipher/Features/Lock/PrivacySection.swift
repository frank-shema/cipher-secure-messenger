import CipherDesign
import SwiftUI

/// Flip-to-hide switch. Greyed out, not hidden, on hardware without motion sensors so the person learns
/// the feature exists.
struct PrivacySection: View {
    let monitor: FlipToHideMonitor

    var body: some View {
        SectionCard(title: String(localized: "lock.section.privacy", defaultValue: "Shoulder-surf protection")) {
            Toggle(isOn: Binding(get: { monitor.isEnabled && monitor.isSupported }, set: { monitor.isEnabled = $0 })) {
                SettingsRow(
                    icon: "iphone.gen3.radiowaves.left.and.right",
                    title: String(localized: "privacy.flipToHide.title", defaultValue: "Flip to hide"),
                    detail: monitor.isSupported
                        ? String(localized: "privacy.flipToHide.detail", defaultValue: "Turn your phone face down to blur the screen")
                        : String(localized: "privacy.flipToHide.unsupported",
                                 defaultValue: "Not available on this device"),
                    showsChevron: false
                )
            }
            .tint(CipherColor.accent)
            .disabled(!monitor.isSupported)
            Divider().overlay(CipherColor.divider).padding(.vertical, CipherSpacing.md)
            SettingsRow(
                icon: "rectangle.on.rectangle.slash",
                title: String(localized: "privacy.switcher.title", defaultValue: "App switcher"),
                detail: String(localized: "privacy.switcher.detail",
                               defaultValue: "Always covered. Cipher never shows a message in the switcher."),
                showsChevron: false
            )
        }
    }
}

#Preview {
    PrivacySection(monitor: FlipToHideMonitor(source: PreviewGravitySource()))
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
