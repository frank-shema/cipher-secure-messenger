import CipherCore
import CipherDesign
import SwiftUI

/// One message in the Server's-Eye split: what the person sees on the left, what the relay stored
/// on the right. Both halves sit in one row so the two columns can never scroll apart.
struct ServersEyeRow: View {
    let message: Message
    let envelope: Envelope?
    let contactName: String

    private var isOutgoing: Bool { message.direction == .outgoing }

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            humanSide
                .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
            Rectangle()
                .fill(CipherColor.divider)
                .frame(width: 1)
            serverSide
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, CipherSpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private var humanSide: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
            Text(isOutgoing ? String(localized: "chat.a11y.you", defaultValue: "You") : contactName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CipherColor.textSecondary)
            Text(MessageFormatting.preview(for: message))
                .font(.footnote)
                .foregroundStyle(message.content.isTampered ? CipherColor.danger : message.direction.primaryTextColor)
                .lineLimit(4)
                .multilineTextAlignment(isOutgoing ? .trailing : .leading)
                .padding(.horizontal, CipherSpacing.sm + 2)
                .padding(.vertical, CipherSpacing.xs + 2)
                .background {
                    if message.content.isTampered {
                        MessageBubbleShape(tail: .none, radius: CipherRadius.md).stroke(CipherColor.danger, lineWidth: 1)
                    } else if isOutgoing {
                        MessageBubbleShape(tail: .trailing, radius: CipherRadius.md).fill(CipherGradient.outgoingBubble)
                    } else {
                        MessageBubbleShape(tail: .leading, radius: CipherRadius.md).fill(CipherColor.bubbleIncoming)
                    }
                }
            Text(MessageFormatting.time(message.effectiveTimestamp))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(CipherColor.textSecondary)
        }
    }

    @ViewBuilder
    private var serverSide: some View {
        if let envelope {
            ServerEyeRawView(fields: MessageFormatting.serverFields(for: envelope))
                .font(CipherTypography.monoSmall)
        } else if message.status == .sending || message.status == .failed {
            Label(String(localized: "serversEye.row.notUploaded", defaultValue: "Nothing stored yet"), systemImage: "icloud.slash")
                .font(.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .padding(CipherSpacing.sm)
        } else {
            SkeletonView()
                .frame(height: 96)
        }
    }
}

#Preview {
    let messages = PreviewMessaging.sampleMessages
    let provider = PreviewEnvelopeProvider(store: PreviewMessagingStore.seeded(now: PreviewMessaging.frozenNow))
    ScrollView {
        VStack(spacing: 0) {
            ForEach(messages.prefix(4)) { message in
                ServersEyeRowPreview(message: message, provider: provider)
            }
        }
        .padding(.horizontal, CipherSpacing.md)
    }
    .background(CipherColor.background)
}

private struct ServersEyeRowPreview: View {
    let message: Message
    let provider: PreviewEnvelopeProvider
    @State private var envelope: Envelope?

    var body: some View {
        ServersEyeRow(message: message, envelope: envelope, contactName: "Bob")
            .task { envelope = try? await provider.envelope(for: message.id) }
    }
}
