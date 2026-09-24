import CipherDesign
import SwiftUI

extension View {
    /// Injects the full app environment for a `#Preview`: the container's router and toast center plus
    /// an `AppSession` started in `state`, so any screen can be previewed at any point of the flow.
    /// A `ready` state also brings the preview messaging runtime up, so the inbox and chats have data.
    /// `RootView` hosts toasts itself; a preview of an inner screen adds `.toastHost()` when it needs one.
    @MainActor
    func previewEnvironment(_ container: AppContainer, state: AppSession.State = .signedOut) -> some View {
        let session = AppSession(container: container, initialState: state, stepDwell: .milliseconds(900))
        return self
            .environment(container)
            .environment(session)
            .environment(container.router)
            .environment(container.toastCenter)
            .task {
                guard case .ready(let ready) = state else { return }
                await container.messaging.sessionDidBecomeReady(ready)
            }
    }
}
