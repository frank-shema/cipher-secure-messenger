import CipherCore
import CipherDesign
import SwiftUI

/// `Route.serversEye`: the split view of a conversation as this device sees it and as the relay
/// stores it, pushed onto the main stack. The chat's own eye button presents the same view modally.
struct ServersEyeScreen: View {
    let conversationId: ConversationID

    @Environment(AppContainer.self) private var container
    @State private var loaded: (messages: [Message], contactName: String)?
    @State private var isMissing = false

    var body: some View {
        Group {
            if let loaded, let surface = container.messaging.surface {
                ServersEyeView(
                    messages: loaded.messages,
                    contactName: loaded.contactName,
                    envelopes: surface.chat.envelopes,
                    presentation: .pushed
                )
            } else if isMissing {
                EmptyStateView(
                    icon: "eye.slash",
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
        guard let surface = container.messaging.surface,
              let conversation = await surface.conversation(id: conversationId) else {
            isMissing = true
            return
        }
        do {
            let messages = try await surface.chat.messages.fetch(conversationId: conversationId, limit: 200, before: nil)
            loaded = (messages, conversation.contact.user.displayName)
            isMissing = false
        } catch {
            AppLog.messaging.error("servers-eye load failed: \(String(describing: type(of: error)), privacy: .public)")
            isMissing = true
        }
    }
}

#Preview {
    NavigationStack {
        ServersEyeScreen(conversationId: MessagingFixtures.bobConversationId)
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
