import CipherCore
import CipherDesign
import SwiftUI

/// A message whose signature, replay check or decryption failed. Nothing from it is shown; the
/// bubble explains what failed so the person can decide whether to re-verify the contact.
struct TamperedMessageView: View {
    let message: Message
    let reason: TamperReason
    let tail: MessageBubbleShape.Tail
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            HStack(spacing: CipherSpacing.sm) {
                ShieldBadge(state: .warning, size: 18)
                Text(String(localized: "chat.tampered.title", defaultValue: "Message could not be verified"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CipherColor.danger)
            }
            Text(MessageFormatting.tamperExplanation(for: reason))
                .font(.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(reason.rawValue)
                    .font(CipherTypography.monoSmall)
                    .foregroundStyle(CipherColor.danger.opacity(0.8))
                Spacer()
                BubbleMetaView(message: message, now: now)
            }
        }
        .padding(.horizontal, CipherSpacing.md)
        .padding(.vertical, CipherSpacing.sm + 2)
        .background(MessageBubbleShape(tail: tail).fill(CipherColor.danger.opacity(0.08)))
        .overlay(MessageBubbleShape(tail: tail).stroke(CipherColor.danger.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "chat.tampered.a11y",
                                   defaultValue: "Unverified message. \(MessageFormatting.tamperExplanation(for: reason))"))
    }
}

#Preview {
    let messages = PreviewMessaging.sampleMessages
    VStack(spacing: CipherSpacing.md) {
        ForEach(TamperReason.allCases, id: \.self) { reason in
            if let tampered = messages.first(where: { $0.content.isTampered }) {
                TamperedMessageView(message: tampered, reason: reason, tail: .leading, now: PreviewMessaging.frozenNow)
            }
        }
    }
    .padding()
    .background(CipherColor.background)
}
