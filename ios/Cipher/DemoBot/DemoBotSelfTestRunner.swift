#if DEBUG
import CipherCore
import CipherNetworking
import Foundation
import Observation

/// Drives the self-test against the app's real composition root. It deliberately bypasses `AppSession`
/// and the normal UI so there is exactly one consumer of the socket and one owner of the outcome.
@MainActor
@Observable
final class DemoBotSelfTestRunner {
    enum Step: Hashable {
        case idle
        case signingIn
        case publishingKeys
        case buildingStack
        case startingEcho
        case connecting
        case startingConversation
        case awaitingReply
        case finished(DemoBotSelfTest.Outcome)
    }

    private(set) var step: Step

    @ObservationIgnored private let container: AppContainer
    @ObservationIgnored private let command: DemoBotSelfTest.Command
    @ObservationIgnored private let configuration: DemoBotConfiguration
    @ObservationIgnored private let bot: DemoBot

    init(container: AppContainer, command: DemoBotSelfTest.Command, initialStep: Step = .idle) {
        self.container = container
        self.command = command
        self.configuration = DemoBotConfiguration(endpoints: container.endpoints)
        self.bot = DemoBot(configuration: configuration, memory: DemoBotMemory(defaults: container.defaults))
        self.step = initialStep
    }

    var username: String {
        command.username
    }

    func run() async -> DemoBotSelfTest.Outcome {
        guard step == .idle else {
            if case .finished(let outcome) = step { return outcome }
            return .fail(reason: "alreadyRunning")
        }
        let outcome: DemoBotSelfTest.Outcome
        do {
            outcome = try await execute()
        } catch {
            outcome = .fail(reason: DemoBotSelfTest.reason(for: error))
        }
        await bot.stop()
        step = .finished(outcome)
        return outcome
    }

    // MARK: - Steps

    private func execute() async throws -> DemoBotSelfTest.Outcome {
        step = .signingIn
        let session = try await signIn()
        step = .publishingKeys
        try await publishKeys(for: session)
        step = .buildingStack
        let stack = try await buildStack(for: session)
        step = .startingEcho
        try await bot.start()
        try await Self.awaitOnline(bot)
        step = .connecting
        await stack.realtime.connect()
        try await Self.awaitConnected(stack.realtime)
        let pump = Task {
            for await event in await stack.realtime.events where !Task.isCancelled {
                _ = try? await stack.handleRealtimeEvent.execute(event)
            }
        }
        defer { pump.cancel() }
        step = .startingConversation
        let conversation = try await stack.startConversation.execute(username: configuration.credentials.username)
        step = .awaitingReply
        let updates = await stack.observeConversation.execute(conversationId: conversation.id)
        let sentAt = Date()
        let probe = MessagePayload.text(DemoBotSelfTest.probe)
        let sent = try await stack.sendMessage.execute(conversationId: conversation.id, payload: probe, expiresAt: nil)
        guard sent.status != .failed else { throw DemoBotError.sendFailed }
        let reply = try await Self.awaitReply(in: updates, after: sentAt.addingTimeInterval(-1))
        let elapsed = Int(Date().timeIntervalSince(sentAt) * 1_000)
        await stack.realtime.disconnect()
        DemoBotLog.selfTest.info("reply of \(reply.count) characters after \(elapsed) ms")
        return .pass(replyLength: reply.count, elapsedMillis: elapsed)
    }

    /// The person's account: login, or register on a fresh relay, then persist so the app's own token
    /// provider (which reads the Keychain session) can sign the stack's requests.
    private func signIn() async throws -> Session {
        let auth = container.authGateway
        let session: Session
        do {
            session = try await auth.login(username: command.username, password: command.password)
        } catch let error as APIError {
            guard case .unauthorized = error else { throw error }
            session = try await auth.register(username: command.username, password: command.password, displayName: nil)
        }
        try await container.sessionStore.save(session)
        return session
    }

    private func publishKeys(for session: Session) async throws {
        let bootstrapper = container.identityBootstrapper
        if case .conflict = try await bootstrapper.run(progress: { _ in }) {
            _ = try await bootstrapper.rotate()
        }
        container.publicationRegistry.markPublished(session.user.id)
    }

    private func buildStack(for session: Session) async throws -> MessagingStack {
        do {
            return try await container.makeMessagingStack(for: session)
        } catch {
            DemoBotLog.selfTest.error("messaging stack unavailable: \(String(describing: type(of: error)), privacy: .public)")
            throw DemoBotError.integrationMissing
        }
    }

    // MARK: - Waits

    private nonisolated static func awaitOnline(_ bot: DemoBot) async throws {
        try await DemoBotDeadline.run(seconds: DemoBotSelfTest.connectTimeout, onTimeout: .connectionTimedOut) {
            for await status in await bot.statusUpdates {
                if status.isOnline { return }
                if case .failed(let error) = status { throw error }
            }
            throw DemoBotError.connectionTimedOut
        }
    }

    private nonisolated static func awaitConnected(_ realtime: any RealtimeGateway) async throws {
        try await DemoBotDeadline.run(seconds: DemoBotSelfTest.connectTimeout, onTimeout: .connectionTimedOut) {
            for await state in await realtime.connectionState where state == .connected {
                return
            }
            throw DemoBotError.connectionTimedOut
        }
    }

    private nonisolated static func awaitReply(in updates: AsyncStream<[Message]>, after: Date) async throws -> String {
        try await DemoBotDeadline.run(seconds: DemoBotSelfTest.replyTimeout, onTimeout: .replyTimedOut) {
            for await messages in updates {
                if let body = replyBody(in: messages, after: after) {
                    return body
                }
            }
            throw DemoBotError.replyTimedOut
        }
    }

    /// The first decrypted incoming text newer than the probe; a tampered or reaction row never counts.
    private nonisolated static func replyBody(in messages: [Message], after: Date) -> String? {
        for message in messages where message.direction == .incoming && message.sentAt >= after {
            if case .text(let body) = message.content {
                return body
            }
        }
        return nil
    }
}
#endif
