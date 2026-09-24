import CipherCore
import CipherDesign
import Foundation

/// Drains the WebSocket for one account. Every server event goes through Core's
/// `HandleRealtimeEventUseCase`, which persists a `message.new` and only then acknowledges it, so
/// the relay never drops an envelope this device has not stored. The effect that comes back drives
/// the app-level reactions: haptics, the key-change toast, typing fan-out, the raw envelope for the
/// Server's-Eye view and the other side's disappearing-timer changes.
///
/// Events are handled one at a time, in arrival order, because the relay pushes a sender's messages
/// in counter order and the replay guard expects to see them that way.
@MainActor
final class RealtimeEventPump {
    var onConnectionChange: @MainActor (RealtimeConnectionState) -> Void = { _ in }

    private let stack: MessagingStack
    private let typing: RealtimeTypingSignaller
    private let timerSync: DisappearingTimerSync
    private let haptics: any HapticEngine
    private let toasts: ToastCenter
    private var eventTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?

    init(
        stack: MessagingStack,
        typing: RealtimeTypingSignaller,
        timerSync: DisappearingTimerSync,
        haptics: any HapticEngine,
        toasts: ToastCenter
    ) {
        self.stack = stack
        self.typing = typing
        self.timerSync = timerSync
        self.haptics = haptics
        self.toasts = toasts
    }

    func start() {
        guard eventTask == nil else { return }
        let stack = stack
        eventTask = Task { [weak self] in
            let events = await stack.realtime.events
            for await event in events {
                guard !Task.isCancelled, let self else { return }
                await self.handle(event)
            }
        }
        stateTask = Task { [weak self] in
            let states = await stack.realtime.connectionState
            for await state in states {
                guard !Task.isCancelled, let self else { return }
                self.connectionDidChange(state)
            }
        }
    }

    func stop() {
        eventTask?.cancel()
        stateTask?.cancel()
        syncTask?.cancel()
        eventTask = nil
        stateTask = nil
        syncTask = nil
    }

    // MARK: Events

    private func handle(_ event: ServerEvent) async {
        do {
            let effect = try await stack.handleRealtimeEvent.execute(event)
            await apply(effect, from: event)
        } catch {
            let name = event.type.rawValue
            AppLog.realtime.error("event \(name, privacy: .public) failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func apply(_ effect: RealtimeEffect, from event: ServerEvent) async {
        switch effect {
        case .messageReceived(let message):
            await didReceive(message, from: event)
        case .statusUpdated(_, _, let status):
            if status == .delivered { haptics.play(.delivered) }
            if status == .read { haptics.play(.read) }
        case .typing(let signal):
            await typing.dispatch(signal)
        case .keyChanged(let userId, let trust):
            guard case .keyChanged = trust else { return }
            await warnKeyChanged(for: userId)
        case .serverError(let code, _):
            AppLog.realtime.error("relay error \(code, privacy: .public)")
            haptics.play(.warning)
        case .presenceUpdated, .none:
            break
        }
    }

    private func didReceive(_ message: Message, from event: ServerEvent) async {
        if case .messageNew(let stored) = event, message.direction == .incoming, let recorder = stack.rawEnvelopes {
            do {
                try await recorder.attachRawEnvelope(messageId: message.id, envelope: stored.envelope)
            } catch {
                AppLog.realtime.debug("raw envelope not attached for \(message.id.description, privacy: .public)")
            }
        }
        do {
            try await timerSync.apply(message)
        } catch {
            AppLog.realtime.error("timer notice not applied: \(String(describing: type(of: error)), privacy: .public)")
        }
        if message.content.isTampered {
            haptics.play(.warning)
        }
    }

    private func warnKeyChanged(for userId: UserID) async {
        haptics.play(.keyChanged)
        let name = (try? await stack.contacts.fetch(userId: userId))?.user.displayName
            ?? String(localized: "realtime.keyChanged.fallbackName", defaultValue: "A contact")
        toasts.show(
            String(localized: "realtime.keyChanged.toast", defaultValue: "\(name)'s safety keys changed. Verify them before you continue."),
            style: .warning,
            systemImage: "key.slash"
        )
    }

    // MARK: Connection

    private func connectionDidChange(_ state: RealtimeConnectionState) {
        onConnectionChange(state)
        guard case .connected = state else { return }
        AppLog.realtime.info("socket connected; flushing outbox and syncing")
        syncTask?.cancel()
        let catalog = ConversationCatalogSync(stack: stack, timerSync: timerSync)
        syncTask = Task { await catalog.run() }
    }
}
