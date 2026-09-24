import CipherDesign
import SwiftUI

@main
struct CipherApp: App {
    @State private var container: AppContainer
    @State private var session: AppSession

    init() {
        let container = AppContainer.live()
        let session = AppSession(container: container)
        #if DEBUG
        // The runtime is built before `onAuthenticated` fires, so the surface is already there when it
        // exists; when it failed, Echo simply waits for the next ready session.
        session.onAuthenticated = { [container] ready in
            let messaging = container.messaging
            container.demoBot.sessionDidBecomeReady(ready, starter: messaging.isDecoy ? nil : messaging.surface?.list.start)
        }
        session.onSignedOut = { [container] in
            container.demoBot.sessionDidEnd()
        }
        #endif
        _container = State(initialValue: container)
        _session = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let command = DemoBotWiring.selfTestCommand() {
                    DemoBotSelfTestView(command: command)
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
            .environment(container)
            .environment(session)
            .environment(container.router)
            .environment(container.toastCenter)
        }
    }
}
