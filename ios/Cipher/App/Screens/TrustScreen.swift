import CipherCore
import CipherDesign
import SwiftUI

/// `Route.trust`: "Why this chat is secure" as a pushed screen, for deep links and the inbox. The chat
/// header presents the same sheet directly. Actions route to verification and apply the timer through
/// the same use case the chat uses, so the transcript gets the notice either way.
struct TrustScreen: View {
    let conversationId: ConversationID

    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var conversation: Conversation?
    @State private var isMissing = false

    var body: some View {
        Group {
            if let conversation, let surface = container.messaging.surface {
                TrustSheetView(
                    viewModel: TrustRingViewModel(
                        conversation: conversation,
                        evaluator: surface.chat.trust,
                        contacts: surface.chat.contacts
                    ),
                    actions: actions(for: conversation, on: surface),
                    presentation: .pushed
                )
            } else if isMissing {
                EmptyStateView(
                    icon: "questionmark.circle",
                    title: String(localized: "trust.error.notFound.title", defaultValue: "Conversation not found"),
                    message: String(localized: "trust.error.notFound", defaultValue: "This conversation is no longer on this device.")
                )
            } else {
                ProgressView(String(localized: "trust.loading", defaultValue: "Checking this chat's protections…"))
                    .tint(CipherColor.accent)
            }
        }
        .background(CipherColor.background.ignoresSafeArea())
        .task(id: container.messaging.surface?.id) { await load() }
    }

    private func actions(for conversation: Conversation, on surface: MessagingSurface) -> TrustActions {
        let contactId = conversation.contact.id
        return TrustActions(
            onVerifyKeys: { router.navigate(to: .verify(contactId)) },
            onEnableDisappearing: { seconds in
                Task {
                    do {
                        let timer = DisappearingTimer(seconds: seconds)
                        try await surface.chat.changeTimer.execute(conversationId: conversationId, timer: timer)
                    } catch {
                        container.toastCenter.show(PresentableProblem(error: error).detail, style: .error, systemImage: "timer")
                    }
                }
            },
            onReviewKeyChange: { router.navigate(to: .verify(contactId)) }
        )
    }

    private func load() async {
        guard let surface = container.messaging.surface,
              let found = await surface.conversation(id: conversationId) else {
            isMissing = true
            return
        }
        conversation = found
        isMissing = false
    }
}

#Preview {
    NavigationStack {
        TrustScreen(conversationId: MessagingFixtures.bobConversationId)
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
