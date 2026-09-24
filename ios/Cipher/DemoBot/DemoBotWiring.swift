#if DEBUG
import CipherCore
import CipherNetworking
import Foundation

/// One factory and two session hooks: everything the composition root does to give the app Echo.
///
/// The controller lives as long as the process (it watches the Settings switch), so `AppContainer`
/// keeps it; the session hooks are one line each in `AppSession.onAuthenticated` / `onSignedOut`.
/// Echo never exists outside DEBUG: every type here is compiled out of release builds, and the
/// container's property should sit under the same `#if DEBUG`.
enum DemoBotWiring {
    /// Builds the controller over the relay the app itself talks to (Settings override included),
    /// remembering greeted accounts and the on/off switch in `defaults`.
    @MainActor
    static func makeController(api: APIConfiguration, defaults: UserDefaults) -> DemoBotController {
        DemoBotController(configuration: DemoBotConfiguration(api: api), defaults: defaults)
    }

    /// Same as `makeController(api:defaults:)` from the app's resolved endpoints, which is what the
    /// container has at hand.
    @MainActor
    static func makeController(endpoints: ServerEndpoints, defaults: UserDefaults) -> DemoBotController {
        DemoBotController(configuration: DemoBotConfiguration(endpoints: endpoints), defaults: defaults)
    }

    /// The `--self-test echo <username> <password>` launch argument, when present. The root view
    /// shows `DemoBotSelfTestView(command:)` instead of the normal flow for it.
    static func selfTestCommand(from arguments: [String] = CommandLine.arguments) -> DemoBotSelfTest.Command? {
        DemoBotSelfTest.command(from: arguments)
    }
}

extension DemoBotController {
    /// `AppSession.onAuthenticated`: brings Echo up (when the switch is on) and creates the person's
    /// conversation with it through their own `ConversationStarting`, so Echo's keys are looked up and
    /// pinned exactly as for any other contact.
    ///
    /// The active surface's `list.start` is the right starter; pass `nil` when no surface came up and
    /// Echo will start again on the next ready session.
    func sessionDidBecomeReady(_ session: Session, starter: (any ConversationStarting)?) {
        guard let starter else {
            DemoBotLog.bot.notice("no messaging surface; Echo waits for the next session")
            return
        }
        sessionDidBecomeReady(session) { username in
            try await starter.execute(username: username)
        }
    }
}
#endif
