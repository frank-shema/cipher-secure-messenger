import CipherDesign
import SwiftUI

/// One selectable pill in the composer's preset row.
struct TimeCapsulePresetChip: View {
    let title: String
    let accessibilityLabel: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CipherSpacing.sm + 2)
                .foregroundStyle(isSelected ? Color(hex: 0x0B0F1A) : CipherColor.accent)
                .background(
                    isSelected ? AnyShapeStyle(CipherGradient.primaryAction) : AnyShapeStyle(CipherColor.accent.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(CipherColor.accent.opacity(isSelected ? 0 : 0.35)))
        }
        .buttonStyle(.plain)
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: isSelected)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    HStack(spacing: CipherSpacing.sm) {
        TimeCapsulePresetChip(title: "30 s", accessibilityLabel: "Thirty seconds", isSelected: false) {}
        TimeCapsulePresetChip(title: "1 hour", accessibilityLabel: "One hour", isSelected: true) {}
        TimeCapsulePresetChip(title: "Custom", accessibilityLabel: "Custom", isSelected: false) {}
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
