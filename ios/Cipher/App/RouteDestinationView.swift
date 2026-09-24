import CipherDesign
import SwiftUI

/// Maps a `Route` to its screen. Routes owned by features that are still landing resolve to a
/// placeholder so navigation never dead-ends; the integrator swaps each case for the real view.
struct RouteDestinationView: View {
    let route: Route

    var body: some View {
        switch route {
        case .settings:
            SettingsView()
        case .lockSettings:
            LockSettingsPlaceholderView()
        case .conversation, .newConversation, .verify, .serversEye, .trust, .attachmentViewer:
            RoutePlaceholderView(route: route)
        }
    }
}

/// A calm "not here yet" screen that names the destination, so a tester knows the tap registered.
struct RoutePlaceholderView: View {
    let route: Route

    var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            EmptyStateView(
                icon: "shippingbox",
                title: title,
                message: String(localized: "route.placeholder.message", defaultValue: "This screen is on its way in a later build.")
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch route {
        case .conversation:
            String(localized: "route.conversation", defaultValue: "Conversation")
        case .newConversation:
            String(localized: "route.newConversation", defaultValue: "New chat")
        case .verify:
            String(localized: "route.verify", defaultValue: "Verify keys")
        case .settings:
            String(localized: "route.settings", defaultValue: "Settings")
        case .serversEye:
            String(localized: "route.serversEye", defaultValue: "Server's eye")
        case .trust:
            String(localized: "route.trust", defaultValue: "Trust")
        case .attachmentViewer:
            String(localized: "route.attachment", defaultValue: "Attachment")
        case .lockSettings:
            String(localized: "route.lockSettings", defaultValue: "App lock")
        }
    }
}

#Preview {
    NavigationStack {
        RouteDestinationView(route: .newConversation)
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
