import Foundation

/// The hooks `AppSession` fires as the app moves between foreground and background and as the session
/// comes and goes. The realtime layer (WebSocket connect/disconnect, outbox flush) plugs in here so the
/// session object never learns about sockets, and so the connection policy can be tested on its own.
protocol RealtimeLifecycle: Sendable {
    /// The person signed in (or a stored session was restored) and identity keys are published.
    func sessionDidBecomeReady() async
    /// The person signed out or the session was invalidated; tear down every connection.
    func sessionDidEnd() async
    /// The scene is active again: reconnect and flush anything queued while backgrounded.
    func applicationDidBecomeActive() async
    /// The scene left the foreground: close the socket so the relay marks the person offline.
    func applicationDidEnterBackground() async
}

/// Default until the realtime layer is wired: records nothing, connects nothing.
struct NoopRealtimeLifecycle: RealtimeLifecycle {
    func sessionDidBecomeReady() async {}
    func sessionDidEnd() async {}
    func applicationDidBecomeActive() async {}
    func applicationDidEnterBackground() async {}
}
