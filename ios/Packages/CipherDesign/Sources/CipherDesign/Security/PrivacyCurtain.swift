import SwiftUI

/// The branded privacy screen shown in the app switcher and while locked:
/// obsidian background, faint glyph rain, a lock glyph and the Cipher wordmark.
///
/// The rain is still when Reduce Motion is on.
public struct PrivacyCurtain: View {
    private let subtitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a privacy curtain.
    /// - Parameter subtitle: The line under the wordmark.
    public init(subtitle: String = "Security you can see and feel") {
        self.subtitle = subtitle
    }

    public var body: some View {
        ZStack {
            CipherColor.background
            GlyphRain(isAnimated: !reduceMotion)
                .opacity(0.6)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.9), .black.opacity(0.9), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            VStack(spacing: CipherSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(CipherColor.accent.opacity(0.14))
                        .frame(width: 96, height: 96)
                        .blur(radius: 12)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(CipherColor.accent)
                        .shadow(color: CipherColor.accent.opacity(0.6), radius: 14)
                }
                Text(verbatim: "Cipher")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textSecondary)
            }
            .padding(CipherSpacing.xl)
            .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cipher is locked. \(subtitle)")
    }
}

#Preview("PrivacyCurtain") {
    PrivacyCurtain()
}
