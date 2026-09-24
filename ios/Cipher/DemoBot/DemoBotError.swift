#if DEBUG
import Foundation

/// Failures of the demo companion. Every case reads well in the Settings status row, which is where a
/// developer learns why the bot is not answering; underlying transport errors are logged by type name
/// only and never embedded here.
enum DemoBotError: Error, LocalizedError, Hashable, Sendable {
    /// Login answered something other than 401, or registration failed. Carries the HTTP status when
    /// there was one, because "relay down" and "relay refused" call for different fixes.
    case signInFailed(status: Int?)
    /// The relay already has an `echo` account with a different password.
    case accountTaken
    case keyPublishFailed
    case storeUnavailable
    case imageGenerationFailed
    case notStarted
    case connectionTimedOut
    case replyTimedOut
    case sendFailed
    /// `AppContainer.messagingStackFactory` still throws `IntegrationError.notWired`.
    case integrationMissing

    var errorDescription: String? {
        switch self {
        case .signInFailed(let status?):
            String(localized: "demo.error.signInFailed.status", defaultValue: "Echo could not sign in (HTTP \(status)).")
        case .signInFailed(nil):
            String(localized: "demo.error.signInFailed", defaultValue: "Echo could not reach the relay to sign in.")
        case .accountTaken:
            String(localized: "demo.error.accountTaken", defaultValue: "The relay's “echo” account uses a different password.")
        case .keyPublishFailed:
            String(localized: "demo.error.keyPublishFailed", defaultValue: "Echo could not publish its keys.")
        case .storeUnavailable:
            String(localized: "demo.error.storeUnavailable", defaultValue: "Echo could not open its in-memory store.")
        case .imageGenerationFailed:
            String(localized: "demo.error.imageGenerationFailed", defaultValue: "Echo could not draw a picture.")
        case .notStarted:
            String(localized: "demo.error.notStarted", defaultValue: "Echo is not running.")
        case .connectionTimedOut:
            String(localized: "demo.error.connectionTimedOut", defaultValue: "The realtime connection did not come up in time.")
        case .replyTimedOut:
            String(localized: "demo.error.replyTimedOut", defaultValue: "Echo did not answer in time.")
        case .sendFailed:
            String(localized: "demo.error.sendFailed", defaultValue: "The message could not be sent.")
        case .integrationMissing:
            String(localized: "demo.error.integrationMissing", defaultValue: "The messaging stack is not wired in this build.")
        }
    }
}
#endif
