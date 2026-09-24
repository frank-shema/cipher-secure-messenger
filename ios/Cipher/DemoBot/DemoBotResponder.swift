#if DEBUG
import CipherCore
import Foundation

/// Carries out a `DemoBotScript.Plan` for one incoming message: react, type, wait, answer, stop
/// typing, then read. A value type that runs on the cooperative pool; the `DemoBot` actor only
/// schedules and cancels it, so a slow picture upload never delays acknowledging the next message.
struct DemoBotResponder: Sendable {
    private let client: DemoBotClient
    private let configuration: DemoBotConfiguration
    private let memory: DemoBotMemory
    private let clock: any Clock
    private let attachmentSender: DemoBotAttachmentSender

    init(client: DemoBotClient, configuration: DemoBotConfiguration, memory: DemoBotMemory, clock: any Clock) {
        self.client = client
        self.configuration = configuration
        self.memory = memory
        self.clock = clock
        self.attachmentSender = DemoBotAttachmentSender(stack: client.stack, attachments: client.attachments)
    }

    func respond(to message: Message) async {
        let conversationId = message.conversationId
        let context = await makeContext(for: message)
        let plan = DemoBotScript.plan(for: message, context: context)
        guard !plan.isSilent else { return }
        if let emoji = plan.reaction {
            await send(.reaction(Reaction(targetId: message.id, emoji: emoji)), in: conversationId, expiresAt: nil)
        }
        await setTyping(true, in: conversationId)
        await pause(configuration.thinkingDelay)
        let replyTo = plan.quotes ? message.id : nil
        for action in plan.actions where !Task.isCancelled {
            await perform(action, in: conversationId, replyTo: replyTo, timer: context.disappearingTimer, seed: context.seed)
        }
        await setTyping(false, in: conversationId)
        if plan.greets, !Task.isCancelled {
            memory.markGreeted(message.senderId)
        }
        await pause(configuration.readReceiptDelay)
        await markRead(conversationId)
    }

    // MARK: - Context

    private func makeContext(for message: Message) async -> DemoBotScript.Context {
        DemoBotScript.Context(
            isFirstContact: !memory.hasGreeted(message.senderId),
            disappearingTimer: await mirroredTimer(for: message),
            capsuleDelay: configuration.capsuleDelay,
            seed: DemoBotRandom.seed(for: message.id)
        )
    }

    /// The relay never sees the disappearing timer and the `disappearing_changed` notice carries no
    /// value, so the only way Echo can learn the conversation's setting is the flag on the messages
    /// themselves. It adopts whatever the last text or attachment used and answers under the same timer.
    private func mirroredTimer(for message: Message) async -> TimeInterval? {
        let carriesTimer: Bool = switch message.content {
        case .text, .attachment: true
        case .reaction, .system, .tampered: false
        }
        guard let conversation = try? await client.stack.conversations.fetch(id: message.conversationId) else { return nil }
        guard carriesTimer else { return conversation.disappearingTimer }
        let timer = message.flags.disappearAfter
        if conversation.disappearingTimer != timer {
            var updated = conversation
            updated.disappearingTimer = timer
            do {
                try await client.stack.conversations.upsert(updated)
            } catch {
                DemoBotLog.reply.notice("could not mirror timer: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        return timer
    }

    // MARK: - Actions

    /// Where and how one reply goes out; shared by every action of a plan.
    private struct Delivery: Sendable {
        var conversationId: ConversationID
        var replyTo: MessageID?
        var timer: TimeInterval?
        var sentAt: Date
        var seed: UInt64

        var expiresAt: Date? {
            timer.map { sentAt.addingTimeInterval($0) }
        }
    }

    private func perform(
        _ action: DemoBotScript.Action,
        in conversationId: ConversationID,
        replyTo: MessageID?,
        timer: TimeInterval?,
        seed: UInt64
    ) async {
        let delivery = Delivery(conversationId: conversationId, replyTo: replyTo, timer: timer, sentAt: clock.now(), seed: seed)
        switch action {
        case .text(let body):
            await send(.text(body, flags: MessageFlags(disappearAfter: timer), replyTo: replyTo), delivery)
        case .whisper(let body):
            await send(.text(body, flags: MessageFlags(whisper: true, disappearAfter: timer), replyTo: replyTo), delivery)
        case .capsule(let body):
            let unlockAt = delivery.sentAt.addingTimeInterval(configuration.capsuleDelay)
            await send(.text(body, flags: MessageFlags(disappearAfter: timer, unlockAt: unlockAt), replyTo: replyTo), delivery)
        case .photo(let caption):
            await sendPhoto(caption: caption, delivery)
        }
    }

    private func sendPhoto(caption: String, _ delivery: Delivery) async {
        let request = DemoBotAttachmentSender.Request(
            conversationId: delivery.conversationId,
            caption: caption,
            flags: MessageFlags(viewOnce: true, disappearAfter: delivery.timer),
            replyTo: delivery.replyTo,
            expiresAt: delivery.expiresAt,
            seed: delivery.seed
        )
        do {
            let message = try await attachmentSender.sendGeneratedImage(request)
            DemoBotLog.reply.info("sent view-once image \(message.id.description, privacy: .public)")
        } catch {
            DemoBotLog.reply.error("photo reply failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func send(_ payload: MessagePayload, _ delivery: Delivery) async {
        await send(payload, in: delivery.conversationId, expiresAt: delivery.expiresAt)
    }

    private func send(_ payload: MessagePayload, in conversationId: ConversationID, expiresAt: Date?) async {
        do {
            let message = try await client.stack.sendMessage.execute(
                conversationId: conversationId,
                payload: payload,
                expiresAt: expiresAt
            )
            let kind = payload.type.rawValue
            let status = message.status.rawValue
            let id = message.id.description
            DemoBotLog.reply.info("sent \(kind, privacy: .public) \(id, privacy: .public) (\(status, privacy: .public))")
        } catch {
            let name = String(describing: type(of: error))
            DemoBotLog.reply.error("send \(payload.type.rawValue, privacy: .public) failed: \(name, privacy: .public)")
        }
    }

    private func setTyping(_ isTyping: Bool, in conversationId: ConversationID) async {
        do {
            let event: ClientEvent = isTyping ? .typingStart(conversationId: conversationId) : .typingStop(conversationId: conversationId)
            try await client.realtime.send(event)
        } catch {
            DemoBotLog.reply.notice("typing signal dropped: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func markRead(_ conversationId: ConversationID) async {
        do {
            let ids = try await client.stack.markConversationRead.execute(conversationId: conversationId)
            DemoBotLog.reply.debug("read \(ids.count) messages in \(conversationId.description, privacy: .public)")
        } catch {
            DemoBotLog.reply.notice("read receipt failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func pause(_ duration: Duration) async {
        do {
            try await Task.sleep(for: duration)
        } catch {
            DemoBotLog.reply.debug("reply cancelled while pausing")
        }
    }
}
#endif
