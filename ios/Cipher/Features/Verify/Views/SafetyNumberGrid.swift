import CipherCore
import CipherDesign
import SwiftUI

/// The safety number as rows of five-digit blocks in mono, copyable, with digits spelled out for
/// VoiceOver so "12345" is read as five digits rather than a quantity.
struct SafetyNumberGrid: View {
    let number: SafetyNumber

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    var body: some View {
        SectionCard(title: String(localized: "verify.safetyNumber.title", defaultValue: "Safety number")) {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                grid
                HStack {
                    Text(String(localized: "verify.safetyNumber.hint", defaultValue: "Same digits on both phones, in the same order."))
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.textSecondary)
                    Spacer(minLength: CipherSpacing.sm)
                    copyButton
                }
            }
        }
    }

    private var grid: some View {
        VStack(spacing: CipherSpacing.sm) {
            ForEach(Array(number.rows(of: 4).enumerated()), id: \.offset) { _, row in
                HStack(spacing: CipherSpacing.md) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, block in
                        Text(block)
                            .font(CipherTypography.mono)
                            .foregroundStyle(CipherColor.glyph)
                            .frame(maxWidth: .infinity)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, CipherSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(CipherColor.surfaceElevated, in: .rect(cornerRadius: CipherRadius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "verify.safetyNumber.a11y", defaultValue: "Safety number"))
        .accessibilityValue(number.accessibilityLabel)
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = number.displayString
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(
                copied
                    ? String(localized: "verify.safetyNumber.copied", defaultValue: "Copied")
                    : String(localized: "verify.safetyNumber.copy", defaultValue: "Copy"),
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .font(CipherTypography.caption)
            .foregroundStyle(CipherColor.accent)
            .contentTransition(.symbolEffect(.replace))
        }
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: copied)
        .accessibilityLabel(String(localized: "verify.safetyNumber.copy.a11y", defaultValue: "Copy safety number"))
    }
}

#Preview {
    SafetyNumberGrid(number: VerifyPreviews.sampleSafetyNumber)
        .padding(CipherSpacing.lg)
        .background(CipherColor.background)
}
