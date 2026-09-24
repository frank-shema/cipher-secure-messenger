import CipherCore
import CipherDesign
import SwiftUI

/// The top of the sheet: a large trust ring around the contact, the percentage, the level headline
/// and a one-line tally. The ring animates as the score changes unless Reduce Motion is on.
struct TrustSheetHeader: View {
    let viewModel: TrustRingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: CipherSpacing.md) {
            TrustRing(score: viewModel.score, segments: viewModel.segments, size: 112) {
                InitialsAvatar(name: viewModel.contact.user.displayName, seed: viewModel.contact.id.description, size: 84)
            }
            .overlay(alignment: .bottomTrailing) {
                ShieldBadge(state: viewModel.contact.trust.shieldState, size: 22)
                    .padding(6)
                    .background(CipherColor.surface, in: Circle())
                    .offset(x: 4, y: 4)
            }
            .padding(.top, CipherSpacing.sm)

            VStack(spacing: CipherSpacing.xs) {
                Text(viewModel.percent, format: .percent)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(TrustRing<EmptyView>.color(for: viewModel.score))
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text(TrustCopy.headline(for: viewModel.level))
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(tally)
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: viewModel.percent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var tally: String {
        if viewModel.reasons.isEmpty {
            return String(localized: "trust.loading", defaultValue: "Checking this chat's protections…")
        }
        return TrustCopy.summary(satisfied: viewModel.satisfiedCount, total: viewModel.reasons.count)
    }

    private var accessibilitySummary: String {
        String(
            localized: "trust.sheet.header.a11y",
            defaultValue: """
            \(viewModel.contact.user.displayName). Trust \(viewModel.percent) percent. \
            \(TrustCopy.headline(for: viewModel.level)). \(tally)
            """
        )
    }
}

#Preview {
    VStack {
        TrustSheetHeader(viewModel: TrustPreview.viewModel(.verified))
        TrustSheetHeader(viewModel: TrustPreview.viewModel(.keyChanged))
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
