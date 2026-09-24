import CipherDesign
import SwiftUI

@main
struct CipherApp: App {
    @State private var container: AppContainer
    @State private var session: AppSession

    init() {
        let container = AppContainer.live()
        _container = State(initialValue: container)
        _session = State(initialValue: AppSession(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(session)
                .environment(container.router)
                .environment(container.toastCenter)
        }
    }
}
