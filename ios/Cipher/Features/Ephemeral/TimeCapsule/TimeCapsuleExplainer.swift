import CipherDesign
import SwiftUI

/// The honest sentence under the picker: what the capsule promises and who keeps the promise. The
/// wording is deliberate: `unlockAt` is inside the ciphertext, so the relay cannot open a capsule
/// early, but it also cannot stop a modified client from doing so. Saying "enforced by the apps"
/// keeps the feature from being mistaken for a server-side guarantee.
struct TimeCapsuleExplainer: View {
    let unlockAt: Date

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundStyle(CipherGradient.violet)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(String(localized: "capsule.explainer.sealedUntil", defaultValue: "Sealed until \(sealedUntil)"))
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                    .contentTransition(.numericText())
                Text(String(
                    localized: "capsule.explainer.body",
                    defaultValue: "The relay cannot open it early — but this is enforced by the apps, not the server."
                ))
                .font(.subheadline)
                .foregroundStyle(CipherColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CipherSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.surface, in: RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous)
                .strokeBorder(CipherColor.accentSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .accessibilityElement(children: .combine)
    }

    private var sealedUntil: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(unlockAt) {
            return unlockAt.formatted(date: .omitted, time: .shortened)
        }
        return unlockAt.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        TimeCapsuleExplainer(unlockAt: PreviewMessaging.frozenNow.addingTimeInterval(3_600))
        TimeCapsuleExplainer(unlockAt: PreviewMessaging.frozenNow.addingTimeInterval(86_400 * 3))
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
