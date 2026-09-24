import CipherDesign
import SwiftUI

/// The onboarding hero: a lock inside three rings that breathe outward like a signal, over a faint
/// glyph rain. With Reduce Motion on, the rings hold a single soft state and the rain is static.
struct AnimatedLockEmblem: View {
    var size: CGFloat = 156
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            GlyphRain(isAnimated: !reduceMotion, tint: CipherColor.accent, columnSpacing: 18)
                .frame(width: size * 1.6, height: size * 1.6)
                .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: size * 0.2, endRadius: size * 0.8))
                .opacity(0.35)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(CipherColor.accent.opacity(0.28 - Double(index) * 0.08), lineWidth: 1.5)
                    .frame(width: ringSize(index), height: ringSize(index))
                    .scaleEffect(breathing ? 1.08 + Double(index) * 0.04 : 1)
                    .opacity(breathing ? 0.55 : 1)
                    .animation(ringAnimation(index), value: breathing)
            }
            Circle()
                .fill(CipherColor.surface)
                .overlay(Circle().fill(CipherGradient.glassSheen))
                .overlay(Circle().strokeBorder(CipherColor.divider, lineWidth: 1))
                .frame(width: size * 0.56, height: size * 0.56)
                .cipherShadow(.glow)
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(CipherGradient.primaryAction)
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating.speed(0.6), isActive: !reduceMotion)
        }
        .frame(width: size, height: size)
        .onAppear { breathing = !reduceMotion }
        .accessibilityHidden(true)
    }

    private func ringSize(_ index: Int) -> CGFloat {
        size * (0.72 + CGFloat(index) * 0.14)
    }

    private func ringAnimation(_ index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(Double(index) * 0.35)
    }
}

#Preview {
    AnimatedLockEmblem()
        .padding(CipherSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CipherColor.background)
}
