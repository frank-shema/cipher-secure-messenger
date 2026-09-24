import CipherCore
import CipherDesign
import SwiftUI

/// A text bubble. Incoming text plays the decrypt reveal the first time it is seen, because the
/// message really was just decrypted on this device; outgoing text pulses through the "sealing"
/// scramble while it is still `.sending`.
struct TextBubble: View {
    let message: Message
    let text: String
    let tail: MessageBubbleShape.Tail
    let isRevealed: Bool
    let now: Date
    let onRevealed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Bool
    @State private var isSealing = false

    init(message: Message, text: String, tail: MessageBubbleShape.Tail, isRevealed: Bool, now: Date, onRevealed: @escaping () -> Void) {
        self.message = message
        self.text = text
        self.tail = tail
        self.isRevealed = isRevealed
        self.now = now
        self.onRevealed = onRevealed
        _reveal = State(initialValue: isRevealed || message.direction == .outgoing)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: CipherSpacing.xs) {
            content
                .font(CipherTypography.body)
                .foregroundStyle(message.direction.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            BubbleMetaView(message: message, now: now)
        }
        .bubbleChrome(direction: message.direction, tail: tail)
        .scrambleOnSend(trigger: isSealing)
        .task(id: message.id) { await playEntranceEffects() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        if message.direction == .incoming {
            DecryptText(text, reveal: reveal, duration: min(0.4 + Double(text.count) * 0.004, 1.2), onCompleted: onRevealed)
                .textSelection(.enabled)
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }

    /// Incoming: flip `reveal` after the first frame so `DecryptText` sees the change and animates.
    /// Outgoing: a short scramble pulse marks the moment the plaintext was sealed.
    private func playEntranceEffects() async {
        if message.direction == .incoming {
            guard !reveal else { return }
            try? await Task.sleep(for: .milliseconds(30))
            reveal = true
        } else if message.status == .sending, !isSealing {
            isSealing = true
            let pulse = reduceMotion ? CipherMotion.Duration.fast : CipherMotion.Duration.standard
            try? await Task.sleep(for: .seconds(pulse))
            isSealing = false
        }
    }

    private var accessibilityLabel: String {
        let who = message.direction == .outgoing
            ? String(localized: "chat.a11y.you", defaultValue: "You")
            : String(localized: "chat.a11y.them", defaultValue: "Them")
        return "\(who): \(text), \(MessageFormatting.time(message.effectiveTimestamp))"
    }
}

#Preview {
    let messages = PreviewMessaging.sampleMessages
    VStack(spacing: CipherSpacing.sm) {
        ForEach(messages.prefix(3)) { message in
            if case .text(let body) = message.content {
                TextBubble(message: message, text: body, tail: message.direction == .outgoing ? .trailing : .leading,
                           isRevealed: false, now: PreviewMessaging.frozenNow) {}
                    .frame(maxWidth: 300, alignment: message.direction == .outgoing ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: message.direction == .outgoing ? .trailing : .leading)
            }
        }
    }
    .padding()
    .background(CipherColor.background)
}
