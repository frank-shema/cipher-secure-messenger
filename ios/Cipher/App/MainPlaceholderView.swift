import CipherDesign
import SwiftUI

/// The signed-in home until the messaging feature lands: the integrator replaces this one view with
/// `ConversationListView` and keeps the navigation shell, toolbar routes and empty state.
struct MainPlaceholderView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            EmptyStateView(
                icon: "lock.shield",
                title: String(localized: "main.empty.title", defaultValue: "No conversations yet"),
                message: String(
                    localized: "main.empty.message",
                    defaultValue: "Start a chat and every message is sealed on this device before it leaves."
                ),
                action: .init(title: String(localized: "main.empty.action", defaultValue: "New message")) {
                    router.navigate(to: .newConversation)
                }
            )
        }
        .navigationTitle(String(localized: "main.title", defaultValue: "Chats"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.navigate(to: .settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(String(localized: "main.toolbar.settings", defaultValue: "Settings"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.navigate(to: .newConversation)
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel(String(localized: "main.toolbar.newChat", defaultValue: "New chat"))
            }
        }
    }
}

#Preview {
    NavigationStack {
        MainPlaceholderView()
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
