import CipherCore
import CipherDesign
import SwiftUI

/// `Route.conversation`: resolves the id against the active surface, builds the `ChatViewModel` and
/// hands it the router-backed routes. The attachments feature installs its pickers on the same view
/// model (`onPickPhoto`, `onPickFile`) and resolves `onOpenAttachment`'s destination.
struct ChatScreen: View {
    let conversationId: ConversationID

    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var viewModel: ChatViewModel?
    @State private var isMissing = false

    var body: some View {
        Group {
            if let viewModel {
                AttachmentsChatView(viewModel: viewModel, feature: container.messaging.surface?.attachments)
            } else if isMissing {
                EmptyStateView(
                    icon: "bubble.left.and.exclamationmark.bubble.right",
                    title: String(localized: "chat.missing.title", defaultValue: "Conversation not found"),
                    message: String(localized: "chat.missing.message", defaultValue: "This conversation is no longer on this device.")
                )
            } else {
                ProgressView()
                    .tint(CipherColor.accent)
                    .accessibilityLabel(String(localized: "chat.opening", defaultValue: "Opening conversation"))
            }
        }
        .background(CipherColor.background.ignoresSafeArea())
        .task(id: container.messaging.surface?.id) { await load() }
    }

    private func load() async {
        guard let surface = container.messaging.surface else {
            viewModel = nil
            return
        }
        guard let conversation = await surface.conversation(id: conversationId) else {
            isMissing = true
            return
        }
        isMissing = false
        viewModel = ChatViewModel(
            conversation: conversation,
            dependencies: surface.chat,
            routes: ChatRoutes(
                onVerify: { router.navigate(to: .verify($0)) },
                onOpenAttachment: { router.navigate(to: .attachmentViewer($0)) }
            ),
            haptics: container.haptics
        )
    }
}

#Preview {
    NavigationStack {
        ChatScreen(conversationId: MessagingFixtures.bobConversationId)
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
