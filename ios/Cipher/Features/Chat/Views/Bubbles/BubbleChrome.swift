import CipherCore
import CipherDesign
import SwiftUI

/// Shared bubble surface: padding, fill and tail. Kept in one modifier so text, attachment and
/// capsule bubbles cannot drift apart visually.
struct BubbleChrome: ViewModifier {
    let direction: MessageDirection
    let tail: MessageBubbleShape.Tail

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CipherSpacing.md)
            .padding(.vertical, CipherSpacing.sm + 2)
            .background {
                if direction == .outgoing {
                    MessageBubbleShape(tail: tail).fill(CipherGradient.outgoingBubble)
                } else {
                    MessageBubbleShape(tail: tail).fill(CipherColor.bubbleIncoming)
                }
            }
            .clipShape(MessageBubbleShape(tail: tail))
    }
}

extension View {
    func bubbleChrome(direction: MessageDirection, tail: MessageBubbleShape.Tail) -> some View {
        modifier(BubbleChrome(direction: direction, tail: tail))
    }
}

extension MessageDirection {
    var primaryTextColor: Color { self == .outgoing ? CipherColor.bubbleOutgoingText : CipherColor.textPrimary }
    var secondaryTextColor: Color { self == .outgoing ? CipherColor.bubbleOutgoingText.opacity(0.75) : CipherColor.textSecondary }
    var horizontalAlignment: HorizontalAlignment { self == .outgoing ? .trailing : .leading }
}

extension GroupedMessage {
    /// Only the last bubble of a run carries a tail; the rest stack flush.
    var tail: MessageBubbleShape.Tail {
        guard isLastInGroup else { return .none }
        return message.direction == .outgoing ? .trailing : .leading
    }
}

/// Time, delivery glyph and (for disappearing messages) the live countdown ring, laid out inside
/// the bubble's bottom-trailing corner. The ring follows the wall clock on its own cadence.
struct BubbleMetaView: View {
    let message: Message

    var body: some View {
        HStack(spacing: CipherSpacing.xs) {
            if let ring = ExpiryCountdownRing(message: message, tint: message.direction.secondaryTextColor, size: 18) {
                ring
            }
            if message.flags.whisper {
                Image(systemName: "ear").font(.caption2).accessibilityHidden(true)
            }
            Text(MessageFormatting.time(message.effectiveTimestamp))
                .font(.caption2.monospacedDigit())
            if message.direction == .outgoing {
                BubbleStatusGlyph(status: message.status.bubbleStatus)
            }
        }
        .foregroundStyle(message.direction.secondaryTextColor)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.md) {
        ForEach(PreviewMessaging.sampleMessages.prefix(3)) { message in
            BubbleMetaView(message: message)
                .bubbleChrome(direction: message.direction, tail: message.direction == .outgoing ? .trailing : .leading)
        }
    }
    .padding()
    .background(CipherColor.background)
}
