import CipherCore
import CipherDesign
import SwiftUI

/// Who is signed in: avatar, display name, handle and the relay's id for support conversations.
struct SettingsAccountCard: View {
    let user: User

    var body: some View {
        SectionCard(title: String(localized: "settings.section.account", defaultValue: "Account")) {
            HStack(spacing: CipherSpacing.lg) {
                InitialsAvatar(name: user.displayName, seed: user.id.description, size: 56)
                VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                    Text(user.displayName)
                        .font(CipherTypography.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                    Text("@" + user.username)
                        .font(CipherTypography.body)
                        .foregroundStyle(CipherColor.textSecondary)
                    Text(user.id.description)
                        .font(CipherTypography.monoSmall)
                        .foregroundStyle(CipherColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .accessibilityLabel(String(localized: "settings.account.idLabel", defaultValue: "Account id"))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    SettingsAccountCard(user: Fixtures.alice)
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
