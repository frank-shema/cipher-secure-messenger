import CipherCore
import Foundation

/// Why a session ended, so the messaging runtime can decide what to keep on disk.
enum SessionEndReason: Hashable, Sendable {
    /// The person chose to sign out: the account's local data leaves with them.
    case signedOut
    /// The relay rejected the refresh token: the same person will sign back in, so local data stays.
    case invalidated
}

/// The hooks `AppSession` fires as the app moves between foreground and background and as the session
/// comes and goes. The messaging runtime (persistence, WebSocket, outbox flush) plugs in here so the
/// session object never learns about sockets, and so the connection policy can be swapped in previews.
protocol RealtimeLifecycle: Sendable {
    /// The person signed in (or a stored session was restored) and identity keys are published.
    func sessionDidBecomeReady(_ session: Session) async
    /// The person signed out or the session was invalidated; tear down every connection.
    func sessionDidEnd(reason: SessionEndReason) async
    /// The scene is active again: reconnect and flush anything queued while backgrounded.
    func applicationDidBecomeActive() async
    /// The scene left the foreground: close the socket so the relay marks the person offline.
    func applicationDidEnterBackground() async
}
