import CipherDesign
import SwiftUI

/// Label on the left, mono value on the right: key versions and dates in the key-change review.
struct KeyChangeFactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CipherSpacing.md) {
            Text(label)
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
            Spacer(minLength: CipherSpacing.sm)
            Text(value)
                .font(CipherTypography.mono)
                .foregroundStyle(CipherColor.glyph)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// An icon with a title and explanation: one plausible cause of a key change.
struct KeyChangeReasonRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(title)
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(detail)
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.lg) {
        KeyChangeFactRow(label: "Keys you had pinned", value: "v1")
        KeyChangeReasonRow(
            icon: "iphone.gen3.badge.exclamationmark", tint: CipherColor.textSecondary,
            title: "Usually: a new phone", detail: "Keys never leave a device."
        )
    }
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
