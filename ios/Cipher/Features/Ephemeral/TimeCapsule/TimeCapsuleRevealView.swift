import CipherDesign
import SwiftUI

/// The decrypt handoff for an opening capsule: cipher glyphs while sealed, then the signature
/// reveal the moment the coordinator marks the message unlocked. Kept separate from the envelope
/// chrome so a bubble can swap the seal for a plain bubble after the reveal finishes.
struct TimeCapsuleRevealView: View {
    let text: String
    let isUnlocked: Bool
    let onRevealed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Bool

    init(text: String, isUnlocked: Bool, onRevealed: @escaping () -> Void = {}) {
        self.text = text
        self.isUnlocked = isUnlocked
        self.onRevealed = onRevealed
        _reveal = State(initialValue: false)
    }

    var body: some View {
        DecryptText(text, reveal: reveal, duration: reduceMotion ? CipherMotion.Duration.fast : 0.9, onCompleted: onRevealed)
            .font(CipherTypography.body)
            .foregroundStyle(CipherColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: isUnlocked) {
                guard isUnlocked, !reveal else { return }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 120))
                guard !Task.isCancelled else { return }
                reveal = true
            }
            .accessibilityLabel(isUnlocked ? text : String(localized: "capsule.reveal.a11y.sealed", defaultValue: "Sealed time capsule"))
    }
}

#Preview {
    struct Demo: View {
        @State private var isUnlocked = false

        var body: some View {
            VStack(alignment: .leading, spacing: CipherSpacing.lg) {
                TimeCapsuleRevealView(text: "Happy birthday. The key is under the third stone.", isUnlocked: isUnlocked)
                Button(isUnlocked ? "Reset" : "Unlock") { isUnlocked.toggle() }
                    .buttonStyle(.cipherGhost)
            }
            .padding(CipherSpacing.xl)
            .background(CipherColor.background)
        }
    }
    return Demo()
}
