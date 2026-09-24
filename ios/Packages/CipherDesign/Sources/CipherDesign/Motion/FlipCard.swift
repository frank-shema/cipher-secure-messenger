import SwiftUI

/// A card that flips in 3D between a front and a back face, with perspective and
/// the hidden face culled. With Reduce Motion on, the faces crossfade instead.
public struct FlipCard<Front: View, Back: View>: View {
    private let isFlipped: Bool
    private let front: Front
    private let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a flip card.
    /// - Parameters:
    ///   - isFlipped: `false` shows `front`, `true` shows `back`.
    ///   - front: The face shown at rest.
    ///   - back: The face shown after flipping.
    public init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }

    public var body: some View {
        ZStack {
            if reduceMotion {
                front.opacity(isFlipped ? 0 : 1).accessibilityHidden(isFlipped)
                back.opacity(isFlipped ? 1 : 0).accessibilityHidden(!isFlipped)
            } else {
                front.modifier(FlipFaceEffect(angle: isFlipped ? 180 : 0, isBack: false))
                back.modifier(FlipFaceEffect(angle: isFlipped ? 180 : 0, isBack: true))
            }
        }
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isFlipped)
        .accessibilityElement(children: .contain)
    }
}

/// Rotates one face of a ``FlipCard`` and hides it while it faces away from the viewer.
struct FlipFaceEffect: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var frontIsVisible: Bool {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return positive < 90 || positive > 270
    }

    private var isVisible: Bool { isBack ? !frontIsVisible : frontIsVisible }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isBack ? angle + 180 : angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(!isVisible)
    }
}

#Preview("FlipCard") {
    struct Demo: View {
        @State private var flipped = false
        var body: some View {
            FlipCard(isFlipped: flipped) {
                face(title: "Safety Number", symbol: "lock.shield.fill", tint: CipherColor.accent)
            } back: {
                face(title: "5F3A 9C21 77E0 B4D8", symbol: "key.fill", tint: CipherColor.accentSecondary)
            }
            .frame(width: 280, height: 170)
            .onTapGesture { flipped.toggle() }
            .padding(CipherSpacing.xxl)
            .background(CipherColor.background)
        }

        func face(title: String, symbol: String, tint: Color) -> some View {
            VStack(spacing: CipherSpacing.md) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(tint)
                Text(title).font(.headline.monospaced()).foregroundStyle(CipherColor.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CipherColor.surfaceElevated, in: RoundedRectangle(cornerRadius: CipherRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.lg).strokeBorder(tint.opacity(0.35)))
        }
    }
    return Demo()
}
