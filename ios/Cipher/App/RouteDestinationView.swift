import CipherCore
import CipherDesign
import SwiftUI

/// Maps a `Route` to its screen. Screens that need the account's messaging surface resolve it through
/// `WithMessagingSurface`, which shows a calm fallback while the runtime is still coming up.
struct RouteDestinationView: View {
    let route: Route

    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router

    var body: some View {
        switch route {
        case .conversation(let id):
            ChatScreen(conversationId: id)
        case .newConversation:
            WithMessagingSurface { surface in
                NewConversationView(start: surface.list.start) { id in
                    router.replace(with: [.conversation(id)])
                }
            }
        case .verify(let userId):
            WithMessagingSurface { surface in
                VerifyContactView(userId: userId, dependencies: surface.verify, haptics: container.haptics)
            }
        case .settings:
            SettingsView()
        case .serversEye(let id):
            ServersEyeScreen(conversationId: id)
        case .trust(let id):
            TrustScreen(conversationId: id)
        case .attachmentViewer:
            RoutePlaceholderView(title: String(localized: "route.attachment", defaultValue: "Attachment"))
        case .lockSettings:
            SettingsLockView(lock: container.appLock, flipToHide: container.flipToHide)
        }
    }
}

/// Resolves the active messaging surface for a screen, or explains why there is none yet.
struct WithMessagingSurface<Content: View>: View {
    @Environment(AppContainer.self) private var container
    @ViewBuilder let content: (MessagingSurface) -> Content

    var body: some View {
        if let surface = container.messaging.surface {
            content(surface)
        } else {
            MessagingUnavailableView()
        }
    }
}

/// A calm "not here yet" screen that names the destination, so a tester knows the tap registered.
struct RoutePlaceholderView: View {
    let title: String

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
}

#Preview("New chat") {
    NavigationStack {
        RouteDestinationView(route: .newConversation)
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}

#Preview("Placeholder") {
    NavigationStack {
        RouteDestinationView(route: .attachmentViewer(MessageID(MessagingFixtures.stableUUID("preview-attachment"))))
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
