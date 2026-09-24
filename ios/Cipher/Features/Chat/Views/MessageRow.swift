import CipherCore
import CipherDesign
import SwiftUI

/// One message in the list: picks the bubble for the content type, stacks the reply quote and
/// reactions around it, and wires the flip to the raw envelope, the context menu and swipe-to-reply.
struct MessageRow: View {
    let item: GroupedMessage
    let viewModel: ChatViewModel

    private var message: Message { item.message }
    private var isOutgoing: Bool { message.direction == .outgoing }
    private var contactName: String { viewModel.contact.user.displayName }

    var body: some View {
        Group {
            if case .system(let event) = message.content {
                SystemMessageView(event: event, contactName: contactName, date: message.effectiveTimestamp, text: noticeText)
                    .padding(.horizontal, CipherSpacing.lg)
            } else {
                bubbleRow
            }
        }
        .padding(.top, item.isFirstInGroup ? CipherSpacing.sm : 2)
        .onAppear { viewModel.markVisible(message.id) }
    }

    /// Timer notices name the new timer; every other system event keeps its generic sentence.
    private var noticeText: String? {
        guard DisappearingChangeNotice.isTimerNotice(message) else { return nil }
        return DisappearingChangeNotice.text(for: message, contactName: contactName)
    }

    private var bubbleRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOutgoing { Spacer(minLength: 56) }
            VStack(alignment: message.direction.horizontalAlignment, spacing: 0) {
                FlipCard(isFlipped: viewModel.flippedMessageIds.contains(message.id)) {
                    front
                } back: {
                    back
                }
                if !message.reactions.isEmpty {
                    ReactionsStrip(reactions: message.reactions, direction: message.direction) { viewModel.react($0, to: message.id) }
                }
                if message.status == .failed {
                    failedLabel
                }
            }
            if !isOutgoing { Spacer(minLength: 56) }
        }
        .padding(.horizontal, CipherSpacing.lg)
    }

    private var front: some View {
        VStack(alignment: message.direction.horizontalAlignment, spacing: 3) {
            if let replyToId = message.replyToId {
                ReplyQuoteView(quoted: viewModel.messagesById[replyToId], contactName: contactName, direction: message.direction)
                    .padding(.horizontal, CipherSpacing.xs)
            }
            bubble
                .whisperBlur(isEnabled: message.flags.whisper && !isOutgoing) { viewModel.haptics.play(.whisperReveal) }
        }
        .messageContextMenu(for: message, viewModel: viewModel)
        .swipeToReply { viewModel.reply(to: message) }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.content {
        case .text(let body):
            if viewModel.showsCapsule(message), let unlockAt = message.flags.unlockAt {
                SealedCapsuleBubble(message: message, text: body, unlockAt: unlockAt, capsules: viewModel.capsules) {
                    viewModel.markRevealed(message.id)
                }
            } else {
                TextBubble(message: message, text: body, tail: item.tail,
                           isRevealed: viewModel.revealedMessageIds.contains(message.id)) {
                    viewModel.markRevealed(message.id)
                }
            }
        case .attachment(let attachment, let caption):
            AttachmentBubble(message: message, attachment: attachment, caption: caption, tail: item.tail,
                             progress: viewModel.uploadProgress[message.id]) {
                viewModel.openAttachment(message.id)
            }
        case .tampered(let reason):
            TamperedMessageView(message: message, reason: reason, tail: item.tail)
        case .reaction, .system:
            EmptyView()
        }
    }

    @ViewBuilder
    private var back: some View {
        if let envelope = viewModel.rawEnvelopes[message.id] {
            ServerEyeRawView(fields: MessageFormatting.serverFields(for: envelope))
                .frame(width: 300)
                .onTapGesture { viewModel.toggleServerView(for: message.id) }
                .accessibilityHint(String(localized: "chat.serverView.a11y.hint", defaultValue: "Double tap to flip back"))
        } else {
            ProgressView()
                .padding()
        }
    }

    private var failedLabel: some View {
        Button {
            viewModel.retry(message.id)
        } label: {
            Label(String(localized: "chat.status.failedRetry", defaultValue: "Not sent. Tap to retry"),
                  systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(CipherColor.danger)
        }
        .buttonStyle(.plain)
        .padding(.top, CipherSpacing.xs)
        .padding(.horizontal, CipherSpacing.xs)
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel()
    let sections = MessageGrouper.sections(from: PreviewMessaging.sampleMessages)
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(sections) { section in
                ForEach(section.groups) { group in
                    ForEach(group.items) { item in
                        MessageRow(item: item, viewModel: viewModel)
                    }
                }
            }
        }
    }
    .background(CipherColor.background)
}
