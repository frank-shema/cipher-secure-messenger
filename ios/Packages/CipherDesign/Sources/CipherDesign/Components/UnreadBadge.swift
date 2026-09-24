import SwiftUI

/// A pill showing an unread count; collapses to nothing at zero and caps at 99+.
public struct UnreadBadge: View {
    private let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a badge for `count`.
    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(CipherTypography.caption.monospacedDigit())
                .foregroundStyle(Color(hex: 0x0B0F1A))
                .padding(.horizontal, CipherSpacing.sm)
                .padding(.vertical, 2)
                .frame(minWidth: 22, minHeight: 22)
                .background(CipherGradient.primaryAction, in: Capsule())
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .snappy, value: count)
                .accessibilityLabel(Text("\(count) unread"))
        }
    }
}

#Preview {
    HStack(spacing: CipherSpacing.lg) {
        UnreadBadge(count: 1)
        UnreadBadge(count: 42)
        UnreadBadge(count: 250)
        UnreadBadge(count: 0)
    }
    .padding()
    .background(CipherColor.background)
}
