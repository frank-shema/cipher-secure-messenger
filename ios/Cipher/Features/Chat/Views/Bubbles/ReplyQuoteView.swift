import CipherCore
import CipherDesign
import SwiftUI

/// The quoted original above a reply bubble. It reuses `MessageFormatting.preview` so a quoted
/// attachment or whisper is described, never exposed.
struct ReplyQuoteView: View {
    let quoted: Message?
    let contactName: String
    let direction: MessageDirection
    var isCompact = false

    private var author: String {
        guard let quoted else { return "" }
        return quoted.direction == .outgoing ? String(localized: "chat.a11y.you", defaultValue: "You") : contactName
    }

    private var previewText: String {
        guard let quoted else {
            return String(localized: "chat.reply.unavailable", defaultValue: "Original message unavailable")
        }
        return MessageFormatting.preview(for: quoted)
    }

    var body: some View {
        HStack(spacing: CipherSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(direction == .outgoing ? CipherColor.bubbleOutgoingText : CipherColor.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                if quoted != nil {
                    Text(author)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(direction == .outgoing ? CipherColor.bubbleOutgoingText : CipherColor.accent)
                }
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(direction.secondaryTextColor)
                    .lineLimit(isCompact ? 1 : 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CipherSpacing.sm)
        .padding(.vertical, CipherSpacing.xs + 2)
        .background(
            direction.primaryTextColor.opacity(direction == .outgoing ? 0.14 : 0.06),
            in: RoundedRectangle(cornerRadius: CipherRadius.sm, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "chat.reply.a11y", defaultValue: "Replying to \(author): \(previewText)"))
    }
}

#Preview {
    let messages = PreviewMessaging.sampleMessages
    VStack(spacing: CipherSpacing.md) {
        ReplyQuoteView(quoted: messages.first, contactName: "Bob", direction: .outgoing)
            .bubbleChrome(direction: .outgoing, tail: .trailing)
        ReplyQuoteView(quoted: messages.dropFirst().first, contactName: "Bob", direction: .incoming)
            .bubbleChrome(direction: .incoming, tail: .leading)
        ReplyQuoteView(quoted: nil, contactName: "Bob", direction: .incoming)
            .bubbleChrome(direction: .incoming, tail: .none)
    }
    .padding()
    .background(CipherColor.background)
}
