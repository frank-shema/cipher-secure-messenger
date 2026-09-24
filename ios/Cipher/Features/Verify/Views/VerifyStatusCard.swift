import CipherCore
import CipherDesign
import SwiftUI

/// The contact's trust state with the action that moves it forward: confirm a spoken comparison,
/// or review a key change. A verified contact shows when, so the person can judge how stale it is.
struct VerifyStatusCard: View {
    let trust: TrustState
    let contactName: String
    let isBusy: Bool
    let canConfirm: Bool
    let onConfirm: () -> Void
    let onReviewKeyChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SectionCard(title: String(localized: "verify.status.title", defaultValue: "Status")) {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                HStack(spacing: CipherSpacing.md) {
                    ShieldBadge(state: trust.shieldState, size: 28)
                    VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                        Text(headline)
                            .font(CipherTypography.headline)
                            .foregroundStyle(CipherColor.textPrimary)
                        Text(detail)
                            .font(CipherTypography.caption)
                            .foregroundStyle(CipherColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                action
            }
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: trust)
        }
    }

    /// Confirming is always possible (a key change is resolved by comparing codes again), and a
    /// pending key change additionally offers the review card.
    private var action: some View {
        VStack(spacing: CipherSpacing.sm) {
            CipherButton(
                String(localized: "verify.status.confirm", defaultValue: "They match — mark as verified"),
                systemImage: "checkmark.shield",
                variant: trust.isVerified ? .ghost : .primary,
                action: onConfirm
            )
            .disabled(isBusy || !canConfirm)
            .accessibilityHint(String(
                localized: "verify.status.confirm.hint",
                defaultValue: "Only after you have compared the emoji or safety number with \(contactName)"
            ))
            if trust.needsAttention {
                CipherButton(
                    String(localized: "verify.status.review", defaultValue: "Review what changed"),
                    systemImage: "exclamationmark.shield",
                    variant: .ghost,
                    action: onReviewKeyChange
                )
            }
        }
    }

    private var headline: String {
        switch trust {
        case .unverified:
            String(localized: "verify.status.unverified", defaultValue: "Not verified yet")
        case .verified:
            String(localized: "verify.status.verified", defaultValue: "Verified")
        case .keyChanged:
            String(localized: "verify.status.keyChanged", defaultValue: "Keys changed")
        }
    }

    private var detail: String {
        switch trust {
        case .unverified:
            String(
                localized: "verify.status.unverified.detail",
                defaultValue: "Messages are encrypted, but nobody has checked that these keys really belong to \(contactName)."
            )
        case .verified(let at):
            String(
                localized: "verify.status.verified.detail",
                defaultValue: """
                    You confirmed \(contactName)'s keys \(at.formatted(.relative(presentation: .named))). \
                    Verified keys stay verified until they change.
                    """
            )
        case .keyChanged(_, let at):
            String(
                localized: "verify.status.keyChanged.detail",
                defaultValue: """
                    \(contactName)'s keys were replaced \(at.formatted(.relative(presentation: .named))). \
                    Verify again before trusting this conversation.
                    """
            )
        }
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        VerifyStatusCard(trust: .unverified, contactName: "Bob", isBusy: false, canConfirm: true, onConfirm: {}, onReviewKeyChange: {})
        VerifyStatusCard(trust: .verified(at: Date().addingTimeInterval(-86_400 * 3)), contactName: "Bob", isBusy: false, canConfirm: true,
                         onConfirm: {}, onReviewKeyChange: {})
        VerifyStatusCard(trust: .keyChanged(previousVersion: 1, at: Date().addingTimeInterval(-3_600)), contactName: "Mara", isBusy: false,
                         canConfirm: true, onConfirm: {}, onReviewKeyChange: {})
    }
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
