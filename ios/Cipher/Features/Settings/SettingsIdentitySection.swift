import CipherDesign
import SwiftUI

/// The two published public keys in mono, each copyable. Private keys are never readable from here.
struct SettingsIdentitySection: View {
    let model: SettingsViewModel

    var body: some View {
        SectionCard(title: String(localized: "settings.section.identity", defaultValue: "Identity keys")) {
            switch model.keys {
            case .loading:
                VStack(alignment: .leading, spacing: CipherSpacing.md) {
                    SkeletonView(cornerRadius: CipherRadius.sm).frame(height: 40)
                    SkeletonView(cornerRadius: CipherRadius.sm).frame(height: 40)
                }
                .accessibilityLabel(String(localized: "settings.identity.loading", defaultValue: "Loading keys"))
            case .loaded(let identityKey, let signingKey):
                VStack(alignment: .leading, spacing: CipherSpacing.md) {
                    keyRow(label: identityLabel, value: identityKey)
                    Divider().overlay(CipherColor.divider)
                    keyRow(label: signingLabel, value: signingKey)
                    Text(footnote)
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .unavailable(let reason):
                HStack(spacing: CipherSpacing.sm) {
                    ShieldBadge(state: .warning)
                    Text(reason)
                        .font(CipherTypography.body)
                        .foregroundStyle(CipherColor.textSecondary)
                }
            }
        }
    }

    private var identityLabel: String {
        String(localized: "settings.identity.identityKey", defaultValue: "Identity key (X25519)")
    }

    private var signingLabel: String {
        String(localized: "settings.identity.signingKey", defaultValue: "Signing key (Ed25519)")
    }

    private var footnote: String {
        String(
            localized: "settings.identity.footnote",
            defaultValue: "These are the public halves the relay stores. Contacts pin them and warn you if they change."
        )
    }

    private func keyRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: CipherSpacing.xs) {
            Text(label)
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
            HStack(alignment: .top, spacing: CipherSpacing.sm) {
                Text(value)
                    .font(CipherTypography.monoSmall)
                    .foregroundStyle(CipherColor.glyph)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    model.copy(value, describedAs: label)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body.weight(.medium))
                        .foregroundStyle(CipherColor.accent)
                        .padding(CipherSpacing.xs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "settings.identity.copy", defaultValue: "Copy") + " " + label)
            }
        }
    }
}

#Preview {
    SettingsIdentitySection(model: SettingsViewModel(container: AppContainer.mock(signedInAs: Fixtures.alice)))
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
