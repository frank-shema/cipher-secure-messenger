import SwiftUI

public extension View {
    /// Blurs the content behind a "Hold to read" hint. Pressing and holding reveals
    /// it; releasing re-blurs. `onReveal` is a hook for haptics or read receipts.
    ///
    /// VoiceOver users get a "Reveal" / "Hide" custom action instead of the hold.
    func whisperBlur(isEnabled: Bool = true, onReveal: (() -> Void)? = nil) -> some View {
        modifier(WhisperBlurModifier(isEnabled: isEnabled, onReveal: onReveal))
    }
}

struct WhisperBlurModifier: ViewModifier {
    let isEnabled: Bool
    let onReveal: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isPressing = false
    @State private var isPinnedOpen = false

    private var isRevealed: Bool { !isEnabled || isPressing || isPinnedOpen }

    func body(content: Content) -> some View {
        content
            .blur(radius: isRevealed ? 0 : 12)
            .overlay {
                if !isRevealed {
                    hint.transition(.opacity)
                }
            }
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: isRevealed)
            .contentShape(Rectangle())
            .gesture(holdGesture, including: isEnabled ? .all : .none)
            .onChange(of: isPressing) { _, pressing in
                if pressing { onReveal?() }
            }
            .accessibilityLabel(isRevealed ? "" : "Hidden message")
            .accessibilityHint(isEnabled ? "Hold to read" : "")
            .accessibilityAction(named: isPinnedOpen ? "Hide" : "Reveal") {
                isPinnedOpen.toggle()
                if isPinnedOpen { onReveal?() }
            }
    }

    private var holdGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15, maximumDistance: 40)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isPressing) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
    }

    private var hint: some View {
        Label("Hold to read", systemImage: "eye.slash.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(CipherColor.textPrimary)
            .padding(.horizontal, CipherSpacing.md)
            .padding(.vertical, CipherSpacing.sm)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(CipherColor.accent.opacity(0.4)))
            .accessibilityHidden(true)
    }
}

#Preview("WhisperBlur") {
    VStack(spacing: CipherSpacing.xl) {
        Text("The safe combination is 41-17-88. Burn after reading.")
            .padding(CipherSpacing.md)
            .foregroundStyle(CipherColor.textPrimary)
            .background(CipherColor.bubbleIncoming, in: RoundedRectangle(cornerRadius: CipherRadius.bubble))
            .whisperBlur()
        Text("Visible message, blur disabled.")
            .padding(CipherSpacing.md)
            .foregroundStyle(CipherColor.textPrimary)
            .background(CipherColor.bubbleIncoming, in: RoundedRectangle(cornerRadius: CipherRadius.bubble))
            .whisperBlur(isEnabled: false)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
