import CipherCore
import CipherDesign
import SwiftUI

/// The signed-in home: the inbox over whichever messaging surface is active (real, preview or decoy),
/// with the socket state as a slim banner. The list rebuilds when the surface is swapped, so a duress
/// unlock never shows a stale real thread.
struct InboxScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router

    var body: some View {
        if let surface = container.messaging.surface {
            InboxContent(surface: surface, connection: container.messaging.connection, routes: routes)
                .id(surface.id)
        } else if let failure = container.messaging.failure {
            MessagingUnavailableView(problem: failure) {
                Task { @MainActor in await container.messaging.retry() }
            }
            .navigationTitle(String(localized: "conversations.title", defaultValue: "Chats"))
        } else {
            InboxLoadingView()
        }
    }

    private var routes: ConversationListRoutes {
        ConversationListRoutes(
            onOpenConversation: { router.navigate(to: .conversation($0)) },
            onNewConversation: { router.navigate(to: .newConversation) },
            onSettings: { router.navigate(to: .settings) }
        )
    }
}

/// Owns the inbox view model for one surface; `InboxScreen` re-creates it per surface id.
private struct InboxContent: View {
    let connection: RealtimeConnectionState
    let routes: ConversationListRoutes

    @State private var viewModel: ConversationListViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(surface: MessagingSurface, connection: RealtimeConnectionState, routes: ConversationListRoutes) {
        self.connection = connection
        self.routes = routes
        _viewModel = State(initialValue: ConversationListViewModel(dependencies: surface.list))
    }

    var body: some View {
        ConversationListView(viewModel: viewModel, routes: routes)
            .safeAreaInset(edge: .top, spacing: 0) {
                ConnectionBanner(state: connection.bannerState)
                    .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: connection)
            }
    }
}

/// Skeleton rows while the account runtime opens its store.
private struct InboxLoadingView: View {
    var body: some View {
        VStack(spacing: CipherSpacing.md) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: CipherSpacing.md) {
                    SkeletonView(cornerRadius: 26).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                        SkeletonView().frame(height: 14).frame(maxWidth: 160)
                        SkeletonView().frame(height: 12)
                    }
                }
            }
            Spacer()
        }
        .padding(CipherSpacing.lg)
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(String(localized: "conversations.title", defaultValue: "Chats"))
        .accessibilityLabel(String(localized: "conversations.loading", defaultValue: "Loading chats"))
    }
}

extension RealtimeConnectionState {
    /// The banner's vocabulary. A socket that has not been asked to connect yet reads as connecting,
    /// because in a signed-in app that is what happens next; "offline" is reserved for a real outage.
    var bannerState: CipherDesign.ConnectionState {
        switch self {
        case .connecting: .connecting
        case .connected: .connected
        case .offline: .offline
        case .disconnected(let retryIn):
            retryIn.map { .reconnecting(in: Int($0.rounded(.up))) } ?? .connecting
        }
    }
}

#Preview("Inbox") {
    NavigationStack {
        InboxScreen()
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}

#Preview("Loading") {
    NavigationStack {
        InboxScreen()
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice))
}
