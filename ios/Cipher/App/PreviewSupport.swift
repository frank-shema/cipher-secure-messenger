import CipherDesign
import SwiftUI

extension View {
    /// Injects the full app environment for a `#Preview`: the container's router and toast center plus
    /// an `AppSession` started in `state`, so any screen can be previewed at any point of the flow.
    /// `RootView` hosts toasts itself; a preview of an inner screen adds `.toastHost()` when it needs one.
    @MainActor
    func previewEnvironment(_ container: AppContainer, state: AppSession.State = .signedOut) -> some View {
        let session = AppSession(container: container, initialState: state, stepDwell: .milliseconds(900))
        return self
            .environment(container)
            .environment(session)
            .environment(container.router)
            .environment(container.toastCenter)
    }
}
