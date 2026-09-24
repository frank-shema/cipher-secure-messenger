import Foundation
import os

/// One frame in either direction. The relay only speaks text frames; `data` exists so a binary frame
/// from a misconfigured proxy is decoded as UTF-8 instead of dropped.
public enum WebSocketMessage: Hashable, Sendable {
    case text(String)
    case data(Data)
}

/// Why a socket ended, as far as the client can tell. `code` is the WebSocket close code when the relay
/// closed the socket; `handshakeStatus` is the HTTP status when the upgrade itself was refused.
public struct WebSocketCloseInfo: Hashable, Sendable {
    public static let authenticationRejectedCode = 4001
    public static let rateLimitedCode = 4008

    public var code: Int?
    public var handshakeStatus: Int?

    public init(code: Int?, handshakeStatus: Int?) {
        self.code = code
        self.handshakeStatus = handshakeStatus
    }

    /// 4001 after the upgrade, or a 401 to the upgrade request itself (PROTOCOL.md §2).
    public var isAuthenticationRejected: Bool {
        code == Self.authenticationRejectedCode || handshakeStatus == 401
    }

    public var isRateLimited: Bool {
        code == Self.rateLimitedCode || handshakeStatus == 429
    }
}

/// A single socket lifetime. `WebSocketClient` creates one per connection attempt through a factory so
/// tests can drive it with a scripted connection instead of a live relay.
public protocol WebSocketConnection: Sendable {
    /// Resolves once the upgrade succeeded; throws when it was refused or the network failed first.
    func open() async throws
    func send(_ message: WebSocketMessage) async throws
    /// Waits for the next frame; throws once the socket is closed or fails.
    func receive() async throws -> WebSocketMessage
    /// Closes with a standard code (1000 normal, 1001 going away). Safe to call more than once.
    func close(code: Int)
    /// Meaningful after `open` or `receive` threw.
    var closeInfo: WebSocketCloseInfo { get }
}

public protocol WebSocketConnectionFactory: Sendable {
    func makeConnection(for request: URLRequest) -> any WebSocketConnection
}

/// Production factory. Uses its own session: the REST session's resource timeout would cut a
/// long-lived socket after a few minutes, and the socket must not share cookies or caches with anything.
public struct URLSessionWebSocketConnectionFactory: WebSocketConnectionFactory {
    private let session: URLSession

    public init(session: URLSession = URLSessionWebSocketConnectionFactory.makeSession()) {
        self.session = session
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }

    public func makeConnection(for request: URLRequest) -> any WebSocketConnection {
        URLSessionWebSocketConnection(task: session.webSocketTask(with: request))
    }
}

/// Wraps a `URLSessionWebSocketTask`. The task itself is thread-safe; the delegate guards the little
/// state it keeps behind a lock, which is what justifies the unchecked conformance.
final class URLSessionWebSocketConnection: WebSocketConnection, @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let delegate: WebSocketTaskDelegate

    init(task: URLSessionWebSocketTask) {
        self.task = task
        self.delegate = WebSocketTaskDelegate()
        task.delegate = delegate
    }

    func open() async throws {
        task.resume()
        try await withTaskCancellationHandler {
            try await delegate.waitUntilOpen()
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    func send(_ message: WebSocketMessage) async throws {
        switch message {
        case let .text(text):
            try await task.send(.string(text))
        case let .data(data):
            try await task.send(.data(data))
        }
    }

    func receive() async throws -> WebSocketMessage {
        switch try await task.receive() {
        case let .string(text):
            return .text(text)
        case let .data(data):
            return .data(data)
        @unknown default:
            throw RealtimeError.transport("unknown frame kind")
        }
    }

    func close(code: Int) {
        task.cancel(with: URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure, reason: nil)
    }

    var closeInfo: WebSocketCloseInfo {
        let delegateInfo = delegate.closeInfo
        let taskCode = task.closeCode == .invalid ? nil : task.closeCode.rawValue
        return WebSocketCloseInfo(
            code: delegateInfo.code ?? taskCode,
            handshakeStatus: delegateInfo.handshakeStatus ?? (task.response as? HTTPURLResponse)?.statusCode
        )
    }
}

/// Turns the delegate callbacks into "is it open yet?" and "why did it end?". Continuations are resumed
/// outside the lock and at most once.
final class WebSocketTaskDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private struct State {
        var isOpen = false
        var openWaiter: CheckedContinuation<Void, any Error>?
        var failure: (any Error)?
        var closeCode: Int?
        var handshakeStatus: Int?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func waitUntilOpen() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let immediate: Result<Void, any Error>? = state.withLock { state in
                if state.isOpen { return .success(()) }
                if let failure = state.failure { return .failure(failure) }
                state.openWaiter = continuation
                return nil
            }
            if let immediate {
                continuation.resume(with: immediate)
            }
        }
    }

    var closeInfo: WebSocketCloseInfo {
        state.withLock { WebSocketCloseInfo(code: $0.closeCode, handshakeStatus: $0.handshakeStatus) }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let waiter = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            state.isOpen = true
            defer { state.openWaiter = nil }
            return state.openWaiter
        }
        waiter?.resume()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let waiter = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            state.closeCode = closeCode.rawValue
            state.failure = state.failure ?? RealtimeError.closed(code: closeCode.rawValue)
            defer { state.openWaiter = nil }
            return state.openWaiter
        }
        waiter?.resume(throwing: RealtimeError.closed(code: closeCode.rawValue))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let status = (task.response as? HTTPURLResponse)?.statusCode
        let failure: any Error = error ?? RealtimeError.closed(code: URLSessionWebSocketTask.CloseCode.normalClosure.rawValue)
        let waiter = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            state.handshakeStatus = status
            state.failure = state.failure ?? failure
            defer { state.openWaiter = nil }
            return state.openWaiter
        }
        waiter?.resume(throwing: failure)
    }
}
