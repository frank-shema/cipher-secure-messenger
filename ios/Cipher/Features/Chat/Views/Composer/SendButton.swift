import CipherDesign
import SwiftUI

/// The send control. Idle it is a quiet circle; once there is something to send it fills with a
/// slowly turning gradient, and a special mode (whisper, capsule, view-once) swaps the arrow for the
/// mode's glyph so what you are about to do is visible right under your thumb.
struct SendButton: View {
    let isEnabled: Bool
    let modeSymbol: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if isEnabled {
                    animatedFill
                } else {
                    Circle().fill(CipherColor.surfaceElevated)
                }
                Image(systemName: modeSymbol ?? "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isEnabled ? CipherColor.bubbleOutgoingText : CipherColor.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 36, height: 36)
            .scaleEffect(isEnabled ? 1 : 0.92)
            .animation(CipherMotion.bouncy.crossfadeIfReduced(reduceMotion), value: isEnabled)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(String(localized: "chat.composer.send.a11y", defaultValue: "Send"))
        .accessibilityHint(modeSymbol == nil
                           ? ""
                           : String(localized: "chat.composer.send.a11y.mode", defaultValue: "A special send mode is on"))
    }

    @ViewBuilder
    private var animatedFill: some View {
        if reduceMotion {
            Circle().fill(CipherGradient.primaryAction)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [CipherColor.accent, CipherColor.bubbleOutgoing, CipherColor.accentSecondary, CipherColor.accent],
                            center: .center,
                            angle: .degrees(angle)
                        )
                    )
                    .overlay(Circle().fill(CipherGradient.glassSheen).blendMode(.softLight))
            }
            .cipherShadow(.glow)
        }
    }
}

#Preview {
    HStack(spacing: CipherSpacing.lg) {
        SendButton(isEnabled: false, modeSymbol: nil) {}
        SendButton(isEnabled: true, modeSymbol: nil) {}
        SendButton(isEnabled: true, modeSymbol: "ear") {}
        SendButton(isEnabled: true, modeSymbol: "envelope.badge.clock") {}
    }
    .padding()
    .background(CipherColor.background)
}
