import SwiftUI

/// A blurred placeholder for view-once media with an eye icon and tap hint.
public struct ViewOnceOverlay: View {
    private let hint: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the overlay.
    /// - Parameter hint: Short instruction shown under the icon.
    public init(hint: String = "Tap to view once") {
        self.hint = hint
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CipherRadius.bubble)
                .fill(CipherGradient.hero)
                .blur(radius: reduceMotion ? 0 : 24)
                .overlay(RoundedRectangle(cornerRadius: CipherRadius.bubble).fill(CipherColor.overlay))
            VStack(spacing: CipherSpacing.sm) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(CipherSpacing.md)
                    .background(Color.white.opacity(0.15), in: Circle())
                Text(hint)
                    .font(CipherTypography.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CipherRadius.bubble))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("View-once media"))
        .accessibilityHint(Text(hint))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ViewOnceOverlay()
        .frame(width: 220, height: 220)
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
