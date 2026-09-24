import CipherDesign
import SwiftUI

/// The result of a scan or a spoken comparison, pinned to the top of the screen. Success glows in
/// accent; a mismatch is unmistakably red because it is the only visible symptom of key substitution.
struct VerificationOutcomeCard: View {
    let outcome: VerificationOutcome
    let contactName: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: outcome.systemImage)
                .font(.title)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(isRevealed || reduceMotion ? 1 : 0.6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(outcome.title)
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(outcome.message(contactName: contactName))
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(CipherColor.textSecondary)
                    .padding(CipherSpacing.xs)
            }
            .accessibilityLabel(String(localized: "verify.outcome.dismiss", defaultValue: "Dismiss"))
        }
        .padding(CipherSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: CipherRadius.lg)
                .fill(CipherColor.surface)
                .overlay(RoundedRectangle(cornerRadius: CipherRadius.lg).fill(tint.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: CipherRadius.lg).strokeBorder(tint.opacity(0.6), lineWidth: 1.5))
        }
        .cipherShadow(outcome.isSuccess ? .glow : .low)
        .onAppear {
            withAnimation(CipherMotion.bouncy.reduced(reduceMotion)) { isRevealed = true }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        outcome.isSuccess ? CipherColor.accent : CipherColor.danger
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        VerificationOutcomeCard(outcome: .matched(.qrCode), contactName: "Bob") {}
        VerificationOutcomeCard(outcome: .keyMismatch, contactName: "Bob") {}
        VerificationOutcomeCard(outcome: .wrongPerson, contactName: "Bob") {}
    }
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
