import SwiftUI

/// One key of the ``PINPadView`` keypad: a large circular target with a pressed state.
struct PINKeyButton<Label: View>: View {
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .frame(width: 76, height: 76)
                .contentShape(Circle())
        }
        .buttonStyle(PINKeyStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PINKeyStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title, design: .rounded).weight(.medium))
            .foregroundStyle(CipherColor.textPrimary)
            .background(
                Circle().fill(configuration.isPressed ? CipherColor.accent.opacity(0.28) : CipherColor.surfaceElevated)
            )
            .overlay(Circle().strokeBorder(CipherColor.textSecondary.opacity(0.15)))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(CipherMotion.snappy.reduced(reduceMotion), value: configuration.isPressed)
    }
}

/// Horizontal shake driven by an animatable `offset`; static when Reduce Motion is on.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var shakes: Int
    var progress: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = travel * sin(progress * .pi * CGFloat(shakes) * 2)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

extension View {
    /// Shakes the view once whenever `trigger` changes.
    func shake(on trigger: Int, reduceMotion: Bool) -> some View {
        modifier(ShakeEffect(travel: reduceMotion ? 0 : 10, shakes: 3, progress: CGFloat(trigger)))
            .animation(.easeInOut(duration: CipherMotion.Duration.standard), value: trigger)
    }
}

#Preview("PIN keys") {
    HStack(spacing: CipherSpacing.lg) {
        PINKeyButton(accessibilityLabel: "1", action: {}) { Text(verbatim: "1") }
        PINKeyButton(accessibilityLabel: "Delete", action: {}) { Image(systemName: "delete.left") }
    }
    .padding(CipherSpacing.xxl)
    .background(CipherColor.background)
}
