import CipherCore
import CipherDesign
import SwiftUI

/// Long-press menu for a bubble: six quick reactions, reply, copy (text only), the Server's-Eye flip
/// and local delete. Attached as a modifier so every bubble type gets the same menu.
struct MessageContextMenu: ViewModifier {
    let message: Message
    let viewModel: ChatViewModel

    private var copyableText: String? {
        if case .text(let body) = message.content, !message.flags.whisper { return body }
        return nil
    }

    func body(content: Content) -> some View {
        content.contextMenu {
            ControlGroup {
                ForEach(ChatViewModel.quickReactions, id: \.self) { emoji in
                    Button {
                        viewModel.react(emoji, to: message.id)
                    } label: {
                        Text(emoji)
                    }
                    .accessibilityLabel(String(localized: "chat.menu.react", defaultValue: "React \(emoji)"))
                }
            }
            .controlGroupStyle(.compactMenu)

            Button {
                viewModel.reply(to: message)
            } label: {
                Label(String(localized: "chat.menu.reply", defaultValue: "Reply"), systemImage: "arrowshape.turn.up.left")
            }

            if let copyableText {
                Button {
                    UIPasteboard.general.string = copyableText
                } label: {
                    Label(String(localized: "chat.menu.copy", defaultValue: "Copy"), systemImage: "doc.on.doc")
                }
            }

            Button {
                viewModel.toggleServerView(for: message.id)
            } label: {
                Label(
                    viewModel.flippedMessageIds.contains(message.id)
                        ? String(localized: "chat.menu.serverView.back", defaultValue: "Back to the message")
                        : String(localized: "chat.menu.serverView", defaultValue: "View as the server sees it"),
                    systemImage: "eye.trianglebadge.exclamationmark"
                )
            }

            if message.status == .failed {
                Button {
                    viewModel.retry(message.id)
                } label: {
                    Label(String(localized: "chat.menu.retry", defaultValue: "Try again"), systemImage: "arrow.clockwise")
                }
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteLocally(message.id)
            } label: {
                Label(String(localized: "chat.menu.deleteLocally", defaultValue: "Delete on this device"), systemImage: "trash")
            }
        }
    }
}

extension View {
    func messageContextMenu(for message: Message, viewModel: ChatViewModel) -> some View {
        modifier(MessageContextMenu(message: message, viewModel: viewModel))
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel()
    if let message = PreviewMessaging.sampleMessages.first {
        Text("Long-press me")
            .padding()
            .bubbleChrome(direction: .incoming, tail: .leading)
            .messageContextMenu(for: message, viewModel: viewModel)
            .padding()
            .background(CipherColor.background)
    }
}
