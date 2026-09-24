import CipherDesign
import SwiftUI

/// Relay address override so a physical device can reach a relay on the Mac's LAN address. The value
/// is validated locally and applied at the next launch, because the API client is built once at start.
struct SettingsServerSection: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        SectionCard(title: String(localized: "settings.section.server", defaultValue: "Relay")) {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                Text(activeLabel)
                    .font(CipherTypography.monoSmall)
                    .foregroundStyle(CipherColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                CipherTextField(title: fieldTitle, text: $model.serverURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                if let issue = model.serverIssue {
                    Text(issue)
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.danger)
                } else if model.overrideNeedsRestart {
                    Label(
                        String(localized: "settings.server.restart", defaultValue: "Relaunch Cipher to use the new address."),
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.warning)
                }
                HStack(spacing: CipherSpacing.sm) {
                    CipherButton(String(localized: "settings.server.apply", defaultValue: "Save"), variant: .primary) {
                        model.applyServerURL()
                    }
                    CipherButton(String(localized: "settings.server.reset", defaultValue: "Use default"), variant: .ghost) {
                        model.resetServerURL()
                    }
                }
                Text(footnote)
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension SettingsServerSection {
    var activeLabel: String {
        String(localized: "settings.server.active", defaultValue: "Connected to") + " " + model.activeEndpoints.baseURL.absoluteString
    }

    var fieldTitle: String {
        String(localized: "settings.server.field", defaultValue: "Override, e.g. http://192.168.1.20:8080")
    }

    var footnote: String {
        String(
            localized: "settings.server.footnote",
            defaultValue: "Local addresses may use http. Anything beyond your own network must use https."
        )
    }
}

#Preview {
    SettingsServerSection(model: SettingsViewModel(container: AppContainer.mock(signedInAs: Fixtures.alice)))
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
