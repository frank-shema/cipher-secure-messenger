import CipherCore
import Foundation
import os

/// `RealtimeGateway` over `/ws` (PROTOCOL.md §2). One actor owns the socket, the supervisor task that
/// reconnects it, and the fan-out to subscribers, so every state transition happens in one place.
///
/// Lifecycle: `connect()` starts a supervisor that opens a socket with the current Bearer token, reads
/// frames until the socket dies, then sleeps per `ReconnectPolicy` and tries again. A 4001 close means
/// the token was rejected: the supervisor asks the token provider for a refreshed one before the next
/// attempt and gives up (state `.disconnected(retryIn: nil)`) if that fails. `disconnect()` cancels the
/// supervisor and closes the socket; both calls are idempotent.
///
/// Heartbeat: a `ping` every 25 s keeps the relay's 90 s idle timer from firing. Two consecutive pings
/// without a `pong` mean the socket is dead even though the OS has not noticed (the classic
/// "Wi-Fi to cellular" hang), so the client recycles it rather than waiting for a kernel timeout.
public actor WebSocketClient: RealtimeGateway {
    public static let defaultPingInterval: Duration = .seconds(25)
    static let maxMissedPongs = 2

    private let configuration: APIConfiguration
    private let tokenProvider: any AuthTokenProvider
    private let connections: any WebSocketConnectionFactory
    private let reconnectPolicy: ReconnectPolicy
    private let jitter: any ReconnectJitter
    private let pingInterval: Duration

    private var eventSubscribers: [UUID: AsyncStream<ServerEvent>.Continuation] = [:]
    private var stateSubscribers: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
    private var state: ConnectionState = .disconnected(retryIn: nil)
    private var connection: (any WebSocketConnection)?
    private var supervisor: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var attempt = 0
    private var unansweredPings = 0
    private var generation = 0

    public init(
        configuration: APIConfiguration,
        tokenProvider: any AuthTokenProvider,
        connections: any WebSocketConnectionFactory = URLSessionWebSocketConnectionFactory(),
        reconnectPolicy: ReconnectPolicy = .default,
        jitter: any ReconnectJitter = SystemReconnectJitter(),
        pingInterval: Duration = WebSocketClient.defaultPingInterval
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.connections = connections
        self.reconnectPolicy = reconnectPolicy
        self.jitter = jitter
        self.pingInterval = pingInterval
    }

    // MARK: - RealtimeGateway

    /// A fresh, unbounded stream per call: `message.new` must never be dropped because the consumer
    /// was briefly busy decrypting the previous one.
    public var events: AsyncStream<ServerEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ServerEvent>.makeStream(bufferingPolicy: .unbounded)
        eventSubscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeEventSubscriber(id) }
        }
        return stream
    }

    /// Replays the current state first so a banner that subscribes late shows the truth immediately.
    public var connectionState: AsyncStream<ConnectionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ConnectionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        stateSubscribers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateSubscriber(id) }
        }
        return stream
    }

    public var currentState: ConnectionState {
        state
    }

    public func connect() {
        guard supervisor == nil else { return }
        NetLog.realtime.info("connect requested")
        attempt = 0
        supervisor = Task { await supervise() }
    }

    public func disconnect() {
        guard let supervisor else { return }
        NetLog.realtime.info("disconnect requested")
        supervisor.cancel()
        self.supervisor = nil
        closeCurrentConnection(code: 1_000)
        publish(.disconnected(retryIn: nil))
    }

    public func send(_ event: ClientEvent) async throws(RealtimeError) {
        guard let connection, state == .connected else {
            throw .notConnected
        }
        let text: String
        do {
            text = try RealtimeFrameCodec.encode(event)
        } catch {
            throw .encoding(String(describing: error))
        }
        do {
            try await connection.send(.text(text))
        } catch {
            NetLog.realtime.error("send \(event.type.rawValue, privacy: .public) failed: \(Self.describe(error), privacy: .public)")
            throw .transport(String(describing: error))
        }
    }

    // MARK: - Supervision

    private func supervise() async {
        while !Task.isCancelled {
            let outcome = await runSession()
            guard !Task.isCancelled else { return }
            switch outcome {
            case .signedOut:
                NetLog.realtime.notice("no session; realtime stays down until the next connect()")
                supervisor = nil
                publish(.disconnected(retryIn: nil))
                return
            case .authenticationRejected:
                guard await refreshSession() else {
                    supervisor = nil
                    publish(.disconnected(retryIn: nil))
                    return
                }
            case .offline:
                publish(.offline)
            case .ended:
                break
            }
            let delay = reconnectPolicy.delay(forAttempt: attempt, jitter: jitter)
            attempt += 1
            if outcome != .offline {
                publish(.disconnected(retryIn: delay))
            }
            let plan = "reconnecting in \(delay.formatted(.number.precision(.fractionLength(2))))s attempt=\(attempt)"
            NetLog.realtime.info("\(plan, privacy: .public)")
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
        }
    }

    private func refreshSession() async -> Bool {
        do {
            _ = try await tokenProvider.refresh()
            NetLog.realtime.notice("token refreshed after 4001 close")
            return true
        } catch {
            NetLog.realtime.error("token refresh after 4001 failed: \(Self.describe(error), privacy: .public)")
            return false
        }
    }

    private func runSession() async -> SessionOutcome {
        generation += 1
        let session = generation
        publish(.connecting)

        let token: String?
        do {
            token = try await tokenProvider.accessToken()
        } catch {
            return FailureClassifier.isTransient(error) ? .ended : .signedOut
        }
        guard let token else { return .signedOut }

        var request = URLRequest(url: configuration.webSocketURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let connection = connections.makeConnection(for: request)
        self.connection = connection
        defer { finishSession(session) }

        do {
            try await connection.open()
        } catch {
            NetLog.realtime.error("open failed: \(Self.describe(error), privacy: .public)")
            return SessionOutcome.classify(connection.closeInfo, error: error)
        }

        attempt = 0
        unansweredPings = 0
        publish(.connected)
        NetLog.realtime.info("connected")
        startHeartbeat()

        do {
            while !Task.isCancelled {
                handle(try await connection.receive())
            }
            return .ended
        } catch {
            let outcome = SessionOutcome.classify(connection.closeInfo, error: error)
            NetLog.realtime.notice("socket ended: \(String(describing: outcome), privacy: .public)")
            return outcome
        }
    }

    private func finishSession(_ session: Int) {
        heartbeat?.cancel()
        heartbeat = nil
        if generation == session {
            connection = nil
        }
    }

    /// Type name only: never the description, which for a URLError can include the URL.
    private static func describe(_ error: any Error) -> String {
        String(describing: type(of: error))
    }

    // MARK: - Frames

    private func handle(_ message: WebSocketMessage) {
        let result: Result<ServerEvent, RealtimeFrameError>
        switch message {
        case let .text(text):
            result = Result { () throws(RealtimeFrameError) in try RealtimeFrameCodec.decode(text) }
        case let .data(data):
            result = Result { () throws(RealtimeFrameError) in try RealtimeFrameCodec.decode(data) }
        }
        switch result {
        case let .success(event):
            if case .pong = event {
                unansweredPings = 0
            }
            for continuation in eventSubscribers.values {
                continuation.yield(event)
            }
        case let .failure(error):
            NetLog.realtime.error("dropped frame: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [pingInterval] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: pingInterval)
                } catch {
                    return
                }
                await beat()
            }
        }
    }

    private func beat() async {
        guard let connection, state == .connected else { return }
        if unansweredPings >= Self.maxMissedPongs {
            NetLog.realtime.notice("\(self.unansweredPings, privacy: .public) pings unanswered; recycling socket")
            connection.close(code: 1_001)
            return
        }
        unansweredPings += 1
        do {
            try await send(.ping)
        } catch {
            NetLog.realtime.notice("ping failed; recycling socket")
            connection.close(code: 1_001)
        }
    }

    // MARK: - State

    private func publish(_ newState: ConnectionState) {
        guard newState != state else { return }
        state = newState
        for continuation in stateSubscribers.values {
            continuation.yield(newState)
        }
    }

    private func closeCurrentConnection(code: Int) {
        heartbeat?.cancel()
        heartbeat = nil
        connection?.close(code: code)
        connection = nil
    }

    private func removeEventSubscriber(_ id: UUID) {
        eventSubscribers[id] = nil
    }

    private func removeStateSubscriber(_ id: UUID) {
        stateSubscribers[id] = nil
    }
}

/// Why one socket lifetime ended, reduced to what the supervisor must do next.
private enum SessionOutcome: Hashable {
    case signedOut
    case authenticationRejected
    case offline
    case ended

    static func classify(_ closeInfo: WebSocketCloseInfo, error: any Error) -> SessionOutcome {
        if closeInfo.isAuthenticationRejected {
            return .authenticationRejected
        }
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet || urlError.code == .dataNotAllowed {
            return .offline
        }
        return .ended
    }
}
