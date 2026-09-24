import CipherDesign
import SwiftUI

/// The inline suggestion above the composer, rendering a `SensitiveSuggestion` with localized copy.
/// Same silhouette as the design system's chip so it slots into `ComposerAccessories` unchanged.
struct SensitiveSuggestionChip: View {
    let suggestion: SensitiveSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: SensitiveGuardCopy.symbol(for: suggestion.kind))
                .font(.title3)
                .foregroundStyle(CipherColor.accentSecondary)
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating.speed(0.6), isActive: !reduceMotion)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                Text(suggestion.message)
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAccept) {
                    Label(String(localized: "sensitiveGuard.chip.accept", defaultValue: "Send as view-once"), systemImage: "eye.slash")
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(CipherColor.accentSecondary)
                .accessibilityHint(String(
                    localized: "sensitiveGuard.chip.accept.hint",
                    defaultValue: "Sends this message as view-once and deletes it \(SensitiveGuardCopy.disappearWindow) after it is read"
                ))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CipherColor.textSecondary)
                    .padding(CipherSpacing.sm)
            }
            .accessibilityLabel(String(localized: "sensitiveGuard.chip.dismiss.a11y", defaultValue: "Dismiss suggestion"))
        }
        .padding(CipherSpacing.md)
        .background(CipherColor.surfaceElevated, in: RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous)
                .strokeBorder(CipherColor.accentSecondary.opacity(0.35))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(suggestion.message)
    }
}

#Preview {
    VStack(spacing: CipherSpacing.md) {
        ForEach(SensitiveKind.allCases, id: \.self) { kind in
            SensitiveSuggestionChip(suggestion: SensitiveSuggestion(kind: kind, confidence: 0.9), onAccept: {}, onDismiss: {})
        }
    }
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
