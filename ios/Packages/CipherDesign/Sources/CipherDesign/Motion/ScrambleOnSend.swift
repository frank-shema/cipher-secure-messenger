import SwiftUI

public extension View {
    /// The "locking" moment on send: when `trigger` becomes `true`, the content
    /// dissolves into cipher glyphs while lifting upward and fading out.
    ///
    /// Set `trigger` back to `false` to reset. With Reduce Motion on, only the
    /// crossfade plays.
    func scrambleOnSend(trigger: Bool) -> some View {
        modifier(ScrambleOnSendModifier(trigger: trigger))
    }
}

struct ScrambleOnSendModifier: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    func body(content: Content) -> some View {
        content
            .modifier(ScrambleOnSendEffect(phase: phase, lift: reduceMotion ? 0 : 28))
            .onChange(of: trigger) { _, isSending in
                let animation: Animation = isSending
                    ? .easeIn(duration: CipherMotion.Duration.standard)
                    : .easeOut(duration: CipherMotion.Duration.fast)
                withAnimation(animation.crossfadeIfReduced(reduceMotion)) {
                    phase = isSending ? 1 : 0
                }
            }
    }
}

/// Interpolates blur, glyph noise, lift and fade from `phase` 0 (idle) to 1 (locked).
struct ScrambleOnSendEffect: ViewModifier, Animatable {
    var phase: Double
    var lift: CGFloat

    nonisolated var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content
            .blur(radius: phase * 6)
            .opacity(1 - phase * 0.9)
            .overlay {
                ScrambleGlyphNoise(intensity: sin(phase * .pi))
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            .opacity(1 - max(0, phase - 0.7) / 0.3)
            .offset(y: -lift * phase)
            .accessibilityHidden(phase > 0.5)
    }
}

/// A grid of cipher glyphs whose density and brightness follow `intensity`.
struct ScrambleGlyphNoise: View {
    let intensity: Double

    var body: some View {
        Canvas { context, size in
            guard intensity > 0.01 else { return }
            let cell: CGFloat = 13
            let columns = Int(size.width / cell) + 1
            let rows = Int(size.height / cell) + 1
            let frame = Int(intensity * 12)
            for row in 0..<rows {
                for column in 0..<columns {
                    let index = row * columns + column
                    guard CipherGlyphs.unit(index: index, frame: 0) < intensity * 0.8 else { continue }
                    let glyph = String(CipherGlyphs.glyph(index: index, frame: frame))
                    let point = CGPoint(x: CGFloat(column) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
                    context.opacity = intensity
                    context.draw(
                        Text(glyph)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(CipherColor.accent),
                        at: point
                    )
                }
            }
        }
    }
}

#Preview("ScrambleOnSend") {
    struct Demo: View {
        @State private var sent = false
        var body: some View {
            VStack(spacing: CipherSpacing.xl) {
                Text("Wire the funds before noon. Nobody else knows.")
                    .padding(CipherSpacing.md)
                    .foregroundStyle(.white)
                    .background(CipherColor.bubbleOutgoing, in: RoundedRectangle(cornerRadius: CipherRadius.bubble))
                    .scrambleOnSend(trigger: sent)
                Button(sent ? "Reset" : "Send") { sent.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(CipherColor.accent)
            }
            .padding(CipherSpacing.xl)
            .background(CipherColor.background)
        }
    }
    return Demo()
}
