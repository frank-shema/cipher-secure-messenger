import CipherCore
import CipherDesign
import SwiftUI

/// Emoji chips tucked under a bubble. Tapping a chip toggles that reaction, mirroring the context
/// menu, so removing one does not require finding it in the palette again.
struct ReactionsStrip: View {
    let reactions: [Reaction]
    let direction: MessageDirection
    let onToggle: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: CipherSpacing.xs) {
            ForEach(reactions, id: \.emoji) { reaction in
                Button {
                    onToggle(reaction.emoji)
                } label: {
                    Text(reaction.emoji)
                        .font(.footnote)
                        .padding(.horizontal, CipherSpacing.sm)
                        .padding(.vertical, 3)
                        .background(CipherColor.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(CipherColor.divider))
                        .cipherShadow(.low)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "chat.reaction.a11y", defaultValue: "Reaction \(reaction.emoji)"))
                .accessibilityHint(String(localized: "chat.reaction.a11y.hint", defaultValue: "Double tap to remove"))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(CipherMotion.bouncy.crossfadeIfReduced(reduceMotion), value: reactions.map(\.emoji))
        .padding(.horizontal, CipherSpacing.md)
        .offset(y: -CipherSpacing.sm)
        .frame(maxWidth: .infinity, alignment: direction == .outgoing ? .trailing : .leading)
    }
}

#Preview {
    let target = MessageID()
    VStack(alignment: .leading, spacing: CipherSpacing.lg) {
        ReactionsStrip(reactions: [Reaction(targetId: target, emoji: "🔥"), Reaction(targetId: target, emoji: "👍")],
                       direction: .incoming) { _ in }
        ReactionsStrip(reactions: [Reaction(targetId: target, emoji: "❤️")], direction: .outgoing) { _ in }
    }
    .padding()
    .background(CipherColor.background)
}
