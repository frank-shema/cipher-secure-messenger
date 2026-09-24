import CipherCore
import CipherDesign
import SwiftUI

/// Resolves `Route.trust(conversationId)` into a `TrustSheetView` by fetching the conversation from
/// the local store. The chat screen already holds its conversation and builds the sheet directly;
/// this loader exists for deep links and the inbox, where only the id is known.
struct TrustSheetLoaderView: View {
    let conversationId: ConversationID
    let conversations: any ConversationRepository
    let contacts: any ContactRepository
    let evaluator: any TrustEvaluating
    let actions: TrustActions
    var presentation: ScreenPresentation = .sheet

    @State private var phase: Phase = .loading

    private enum Phase {
        case loading
        case loaded(TrustRingViewModel)
        case missing
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView(String(localized: "trust.loading", defaultValue: "Checking this chat's protections…"))
                    .tint(CipherColor.accent)
            case .loaded(let viewModel):
                TrustSheetView(viewModel: viewModel, actions: actions, presentation: presentation)
            case .missing:
                EmptyStateView(
                    icon: "questionmark.circle",
                    title: String(localized: "trust.error.notFound.title", defaultValue: "Conversation not found"),
                    message: String(localized: "trust.error.notFound", defaultValue: "This conversation is no longer on this device.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CipherColor.background.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        do {
            guard let conversation = try await conversations.fetch(id: conversationId) else {
                phase = .missing
                return
            }
            phase = .loaded(TrustRingViewModel(conversation: conversation, evaluator: evaluator, contacts: contacts))
        } catch {
            TrustLog.trust.error("trust load failed: \(String(describing: type(of: error)), privacy: .public)")
            phase = .missing
        }
    }
}

#Preview("Loaded") {
    let store = PreviewMessagingStore.seeded(now: PreviewMessaging.frozenNow)
    TrustSheetLoaderView(
        conversationId: MessagingFixtures.maraConversationId,
        conversations: store,
        contacts: store,
        evaluator: EvaluateTrustUseCase(conversations: store, preferences: AlwaysOnMetadataStripping()),
        actions: TrustActions()
    )
}

#Preview("Missing") {
    let store = PreviewMessagingStore()
    TrustSheetLoaderView(
        conversationId: ConversationID(),
        conversations: store,
        contacts: store,
        evaluator: EvaluateTrustUseCase(conversations: store, preferences: AlwaysOnMetadataStripping()),
        actions: TrustActions()
    )
}
