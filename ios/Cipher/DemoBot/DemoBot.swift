#if DEBUG
import CipherCore
import Foundation

/// Echo: a second, fully independent Cipher client running in the same process, so a developer can
/// watch two real clients converse through the blind relay without a second device.
///
/// The actor owns the client graph, the two pump tasks (socket events and connection state) and one
/// reply task per answered message. Incoming events go through the same `HandleRealtimeEventUseCase`
/// as the app's own account: envelopes are verified against the person's pinned keys, decrypted,
/// persisted and acknowledged before any reply is even planned.
actor DemoBot {
    enum Status: Hashable, Sendable {
        case stopped
        case signingIn
        case publishingKeys
        case connecting
        case online(User)
        case reconnecting(User)
        case failed(DemoBotError)

        var isOnline: Bool {
            if case .online = self { return true }
            return false
        }

        var user: User? {
            switch self {
            case .online(let user), .reconnecting(let user): user
            case .stopped, .signingIn, .publishingKeys, .connecting, .failed: nil
            }
        }
    }

    private let configuration: DemoBotConfiguration
    private let memory: DemoBotMemory
    private let clock: any Clock

    private var client: DemoBotClient?
    private var responder: DemoBotResponder?
    private var startTask: Task<User, any Error>?
    private var eventPump: Task<Void, Never>?
    private var statePump: Task<Void, Never>?
    private var replies: [MessageID: Task<Void, Never>] = [:]
    private var answered: [MessageID] = []
    private var startedAt: Date?
    private var status: Status = .stopped
    private var subscribers: [UUID: AsyncStream<Status>.Continuation] = [:]

    /// - Parameter memory: the greeted-people record; a `Sendable` wrapper rather than `UserDefaults`
    ///   itself, so the actor can be built from the main actor without sending a non-`Sendable` object.
    init(configuration: DemoBotConfiguration, memory: DemoBotMemory = DemoBotMemory(), clock: any Clock = SystemClock()) {
        self.configuration = configuration
        self.memory = memory
        self.clock = clock
    }

    var currentStatus: Status {
        status
    }

    /// Replays the current status first, so a late subscriber (the Settings row) is right immediately.
    var statusUpdates: AsyncStream<Status> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Status>.makeStream(bufferingPolicy: .bufferingNewest(1))
        subscribers[id] = continuation
        continuation.yield(status)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    // MARK: - Lifecycle

    /// Idempotent: a running bot returns its user; a concurrent start joins the one in flight.
    @discardableResult
    func start() async throws -> User {
        if let client { return client.user }
        if let startTask { return try await startTask.value }
        let task = Task { try await bringUp() }
        startTask = task
        defer { startTask = nil }
        return try await task.value
    }

    func stop() async {
        startTask?.cancel()
        startTask = nil
        eventPump?.cancel()
        statePump?.cancel()
        eventPump = nil
        statePump = nil
        for task in replies.values {
            task.cancel()
        }
        replies = [:]
        responder = nil
        if let client {
            await client.realtime.disconnect()
        }
        client = nil
        startedAt = nil
        publish(.stopped)
        DemoBotLog.bot.info("stopped")
    }

    private func bringUp() async throws -> User {
        let assembled: DemoBotClient
        do {
            assembled = try await DemoBotClient.assemble(configuration: configuration) { [weak self] phase in
                await self?.publish(Self.status(for: phase))
            }
        } catch {
            let failure = (error as? DemoBotError) ?? .signInFailed(status: nil)
            DemoBotLog.bot.error("start failed: \(String(describing: failure), privacy: .public)")
            publish(.failed(failure))
            throw failure
        }
        client = assembled
        responder = DemoBotResponder(client: assembled, configuration: configuration, memory: memory, clock: clock)
        startedAt = clock.now()
        await assembled.realtime.connect()
        statePump = Task { [weak self] in await self?.pumpState(of: assembled) }
        eventPump = Task { [weak self] in await self?.pumpEvents(of: assembled) }
        DemoBotLog.bot.info("started as \(assembled.user.id.description, privacy: .public)")
        return assembled.user
    }

    private static func status(for phase: DemoBotClient.Phase) -> Status {
        switch phase {
        case .signingIn: .signingIn
        case .publishingKeys: .publishingKeys
        case .connecting: .connecting
        }
    }

    // MARK: - Pumps

    private func pumpState(of client: DemoBotClient) async {
        for await state in await client.realtime.connectionState where !Task.isCancelled {
            switch state {
            case .connected:
                publish(.online(client.user))
            case .connecting:
                publish(status.user == nil ? .connecting : .reconnecting(client.user))
            case .disconnected, .offline:
                publish(.reconnecting(client.user))
            }
        }
    }

    private func pumpEvents(of client: DemoBotClient) async {
        for await event in await client.realtime.events where !Task.isCancelled {
            await handle(event, client: client)
        }
    }

    private func handle(_ event: ServerEvent, client: DemoBotClient) async {
        let effect: RealtimeEffect
        do {
            effect = try await client.stack.handleRealtimeEvent.execute(event)
        } catch {
            let name = String(describing: type(of: error))
            DemoBotLog.bot.error("event \(event.type.rawValue, privacy: .public) failed: \(name, privacy: .public)")
            return
        }
        guard case .messageReceived(let message) = effect, message.direction == .incoming else { return }
        guard shouldAnswer(message) else {
            Task { _ = try? await client.stack.markConversationRead.execute(conversationId: message.conversationId) }
            return
        }
        remember(message.id)
        guard let responder else { return }
        DemoBotLog.bot.info("answering \(message.id.description, privacy: .public)")
        replies[message.id] = Task { [weak self] in
            await responder.respond(to: message)
            await self?.replyFinished(message.id)
        }
    }

    /// Answer each message once, and only messages sent while Echo was (about to be) listening; the
    /// backlog the relay replays on connect is read, not answered.
    private func shouldAnswer(_ message: Message) -> Bool {
        guard replies[message.id] == nil, !answered.contains(message.id), let startedAt else { return false }
        guard message.effectiveTimestamp >= startedAt.addingTimeInterval(-configuration.backlogGrace) else {
            DemoBotLog.bot.info("skipping backlog message \(message.id.description, privacy: .public)")
            return false
        }
        return true
    }

    private func remember(_ id: MessageID) {
        answered.append(id)
        if answered.count > 512 {
            answered.removeFirst(256)
        }
    }

    private func replyFinished(_ id: MessageID) {
        replies[id] = nil
    }

    // MARK: - Status

    private func publish(_ newStatus: Status) {
        guard newStatus != status else { return }
        status = newStatus
        for continuation in subscribers.values {
            continuation.yield(newStatus)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}
#endif
