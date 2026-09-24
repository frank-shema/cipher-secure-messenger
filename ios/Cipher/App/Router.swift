import CipherCore
import Foundation
import Observation

/// Every screen reachable from the main navigation stack, keyed by domain identifiers rather than
/// models so a route survives the underlying data changing while it sits in the path.
enum Route: Hashable, Sendable {
    case conversation(ConversationID)
    case newConversation
    case verify(UserID)
    case settings
    case serversEye(ConversationID)
    case trust(ConversationID)
    case attachmentViewer(MessageID)
    case lockSettings
}

/// The one navigation path for the signed-in experience. Owning it here (instead of in each view)
/// lets a realtime event, a notification tap or a sign-out drive navigation from outside the view tree.
@MainActor
@Observable
final class Router {
    var path: [Route] = []

    init(path: [Route] = []) {
        self.path = path
    }

    func navigate(to route: Route) {
        path.append(route)
        AppLog.router.debug("push \(String(describing: route), privacy: .public) depth=\(self.path.count, privacy: .public)")
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Replaces the whole stack, for deep links and for landing on a conversation right after creating it.
    func replace(with routes: [Route]) {
        path = routes
    }
}
