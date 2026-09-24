import SwiftUI

public extension View {
    /// Blurs the conversation and draws a compact privacy curtain over it while
    /// `isHidden` is `true`, e.g. when the phone is face down or backgrounded.
    func flipToHide(isHidden: Bool) -> some View {
        modifier(FlipToHideModifier(isHidden: isHidden))
    }
}

/// The curtain drawn over hidden conversation content.
///
/// Use ``SwiftUI/View/flipToHide(isHidden:)`` to apply it together with the blur.
public struct FlipToHideOverlay: View {
    private let isHidden: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the overlay; it renders nothing while `isHidden` is `false`.
    public init(isHidden: Bool) {
        self.isHidden = isHidden
    }

    public var body: some View {
        ZStack {
            if isHidden {
                CipherColor.background.opacity(0.7)
                GlyphRain(isAnimated: !reduceMotion, columnSpacing: 30).opacity(0.35)
                VStack(spacing: CipherSpacing.sm) {
                    Image(systemName: "eye.slash.fill")
                        .font(.title)
                        .foregroundStyle(CipherColor.accent)
                    Text("Hidden")
                        .font(.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                    Text("Turn your phone over to continue")
                        .font(.footnote)
                        .foregroundStyle(CipherColor.textSecondary)
                }
                .padding(CipherSpacing.xl)
                .background(CipherColor.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
                .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
            }
        }
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isHidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isHidden ? "Conversation hidden" : "")
        .accessibilityHidden(!isHidden)
    }
}

struct FlipToHideModifier: ViewModifier {
    let isHidden: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .blur(radius: isHidden ? 22 : 0)
            .accessibilityHidden(isHidden)
            .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isHidden)
            .overlay { FlipToHideOverlay(isHidden: isHidden) }
    }
}

#Preview("FlipToHide") {
    struct Demo: View {
        @State private var hidden = true
        var body: some View {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                ForEach(0..<6, id: \.self) { index in
                    Text("Message \(index + 1): the drop is at pier nine.")
                        .padding(CipherSpacing.md)
                        .foregroundStyle(CipherColor.textPrimary)
                        .background(CipherColor.bubbleIncoming, in: RoundedRectangle(cornerRadius: CipherRadius.bubble))
                }
            }
            .padding(CipherSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .flipToHide(isHidden: hidden)
            .background(CipherColor.background)
            .onTapGesture { hidden.toggle() }
        }
    }
    return Demo()
}
