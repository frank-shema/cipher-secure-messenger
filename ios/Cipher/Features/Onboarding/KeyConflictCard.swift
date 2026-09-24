import CipherDesign
import SwiftUI

/// Shown when `PUT /keys/me` answered 409: the relay already holds different keys for this account.
/// Nothing is overwritten silently; the person chooses to rotate (contacts are told) or to leave.
struct KeyConflictCard: View {
    let onRotate: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                HStack(spacing: CipherSpacing.sm) {
                    ShieldBadge(state: .warning, size: 22)
                    Text(String(localized: "keygen.conflict.title", defaultValue: "Keys exist on another device"))
                        .font(CipherTypography.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                }
                .accessibilityAddTraits(.isHeader)
                Text(String(
                    localized: "keygen.conflict.body",
                    defaultValue: """
                    This account already published identity keys from another device or install. \
                    Rotating replaces them with this device's keys; your contacts will see a key change and can re-verify you.
                    """
                ))
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                CipherButton(
                    String(localized: "keygen.conflict.rotate", defaultValue: "Rotate keys"),
                    systemImage: "arrow.triangle.2.circlepath",
                    action: onRotate
                )
                CipherButton(String(localized: "keygen.signOut", defaultValue: "Sign out"), variant: .ghost, action: onSignOut)
            }
        }
    }
}

#Preview {
    KeyConflictCard(onRotate: {}, onSignOut: {})
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
