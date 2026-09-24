import CipherCore
import CipherDesign
import Foundation
import Observation

/// What the header shows about the other participant, derived once per change so the view stays dumb.
struct ChatHeaderState: Hashable, Sendable {
    var name: String
    var seed: String
    var subtitle: String
    var isTyping: Bool
    var isOnline: Bool
    var trust: TrustState
    /// Fill of the trust ring, from the live evaluation when it has run.
    var trustScore: Double
    var disappearingTimer: TimeInterval?
}

/// Drives one conversation: the live message list, the composer, typing signals in both directions
/// and the per-message security affordances. It talks to Core only through the ports in
/// `ChatDependencies`, so it never sees ciphertext, keys or the network.
@MainActor
@Observable
final class ChatViewModel {
    let conversationId: ConversationID
    let routes: ChatRoutes

    var conversation: Conversation {
        didSet { trustRing.update(conversation: conversation) }
    }
    private(set) var messages: [Message] = []
    private(set) var messagesById: [MessageID: Message] = [:]
    private(set) var sections: [MessageDaySection] = []
    /// Upload progress per outgoing attachment, reported by the attachments feature.
    var uploadProgress: [MessageID: Double] = [:]
    var isLoadingOlder = false
    var hasOlder = true
    private(set) var isPeerTyping = false
    var sensitiveFinding: SensitiveKind?
    var rawEnvelopes: [MessageID: Envelope] = [:]

    /// Incoming bubbles play the decrypt reveal once; scrolling back must not replay it.
    var revealedMessageIds: Set<MessageID> = []
    /// Bubbles currently flipped to their raw envelope.
    var flippedMessageIds: Set<MessageID> = []

    var draft = "" {
        didSet { draftDidChange() }
    }
    var replyingTo: Message?
    var composer = ComposerOptions()
    var stagedAttachment: StagedAttachment?
    var isTimeCapsulePickerPresented = false
    var isServersEyePresented = false
    var isTrustPresented = false
    var errorMessage: String?

    /// The attachments feature installs these; the composer only surfaces the buttons.
    var onPickPhoto: @MainActor () -> Void = {}
    var onPickFile: @MainActor () -> Void = {}

    let deps: ChatDependencies
    let haptics: any HapticEngine
    /// Opens Time Capsules at their instant; rows register the capsules they show.
    let capsules: TimeCapsuleUnlockCoordinator
    /// Scores the conversation for the header ring and the trust sheet; fed from this model's
    /// contact observation rather than its own, so the two never disagree.
    let trustRing: TrustRingViewModel
    let typingDebouncer: TypingDebouncer
    private var lifecycleTasks: [Task<Void, Never>] = []
    var sensitiveTask: Task<Void, Never>?
    var markReadTask: Task<Void, Never>?
    private var typingTimeoutTask: Task<Void, Never>?
    var olderMessages: [Message] = []
    private var lastIncomingId: MessageID?
    var dismissedSensitiveKind: SensitiveKind?
    let pageSize = 50

    init(
        conversation: Conversation,
        dependencies: ChatDependencies,
        routes: ChatRoutes = ChatRoutes(),
        haptics: any HapticEngine = NoopHapticEngine()
    ) {
        self.conversationId = conversation.id
        self.conversation = conversation
        self.deps = dependencies
        self.routes = routes
        self.haptics = haptics
        self.capsules = TimeCapsuleUnlockCoordinator(haptics: haptics, now: dependencies.now)
        self.trustRing = TrustRingViewModel(conversation: conversation, evaluator: dependencies.trust)
        let typing = dependencies.typing
        let id = conversation.id
        self.typingDebouncer = TypingDebouncer { isTyping in
            Task { await typing.setTyping(isTyping, in: id) }
        }
        capsules.onUnlock = { [weak self] id in self?.markVisible(id) }
    }

    var contact: Contact { conversation.contact }
    var now: Date { deps.now() }
    var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stagedAttachment != nil }

    var header: ChatHeaderState {
        ChatHeaderState(
            name: contact.user.displayName,
            seed: contact.user.id.description,
            subtitle: presenceSubtitle,
            isTyping: isPeerTyping,
            isOnline: contact.presence.online,
            trust: contact.trust,
            trustScore: trustRing.score,
            disappearingTimer: conversation.disappearingTimer
        )
    }

    private var presenceSubtitle: String {
        if contact.presence.online {
            return String(localized: "chat.header.online", defaultValue: "Online")
        }
        if let lastSeen = contact.presence.lastSeenAt {
            let relative = lastSeen.formatted(.relative(presentation: .named))
            return String(localized: "chat.header.lastSeen", defaultValue: "Last seen \(relative)")
        }
        return String(localized: "chat.header.encrypted", defaultValue: "End-to-end encrypted")
    }

    // MARK: Lifecycle

    /// Starts every live stream. Safe to call once per screen appearance; `stop()` tears down.
    func start() {
        guard lifecycleTasks.isEmpty else { return }
        lifecycleTasks = [observeMessages(), observeContact(), observeTyping()]
        trustRing.start()
        ChatLog.chat.info("chat opened conversation=\(self.conversationId.description, privacy: .public)")
    }

    func stop() {
        typingDebouncer.stop()
        lifecycleTasks.forEach { $0.cancel() }
        lifecycleTasks.removeAll()
        sensitiveTask?.cancel()
        markReadTask?.cancel()
        typingTimeoutTask?.cancel()
        trustRing.stop()
    }

    private func observeMessages() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            let stream = await deps.observeMessages.execute(conversationId: conversationId)
            for await batch in stream {
                guard !Task.isCancelled else { return }
                await apply(observed: batch)
            }
        }
    }

    private func observeContact() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            let stream = await deps.contacts.observe(userId: contact.id)
            for await updated in stream {
                guard !Task.isCancelled else { return }
                conversation.contact = updated
            }
        }
    }

    private func observeTyping() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            let stream = await deps.typing.incomingTyping(in: conversationId)
            for await signal in stream {
                guard !Task.isCancelled, signal.userId == contact.id else { continue }
                setPeerTyping(signal.isTyping)
            }
        }
    }

    /// A lost `typing.stop` must not leave the indicator bouncing forever.
    private func setPeerTyping(_ isTyping: Bool) {
        isPeerTyping = isTyping
        typingTimeoutTask?.cancel()
        guard isTyping else { return }
        typingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.isPeerTyping = false
        }
    }

    /// Merges the live window with any older pages already loaded, then regroups off the main actor.
    func apply(observed: [Message]) async {
        var merged: [MessageID: Message] = [:]
        for message in olderMessages { merged[message.id] = message }
        for message in observed { merged[message.id] = message }
        let all = Array(merged.values)
        messages = all.sorted { $0.effectiveTimestamp < $1.effectiveTimestamp }
        messagesById = merged
        let grouped = await Task.detached(priority: .userInitiated) { MessageGrouper.sections(from: all) }.value
        sections = grouped
        let newestIncoming = messages.last { $0.direction == .incoming }?.id
        if let newestIncoming, newestIncoming != lastIncomingId {
            lastIncomingId = newestIncoming
            if isPeerTyping { setPeerTyping(false) }
        }
    }

    /// Rows the expiry sweep deleted: drop them from the paged cache the live window does not cover.
    func messagesDeleted(_ ids: [MessageID]) {
        let gone = Set(ids)
        guard !gone.isEmpty else { return }
        olderMessages.removeAll { gone.contains($0.id) }
        let remaining = messages.filter { !gone.contains($0.id) }
        Task { await apply(observed: remaining) }
    }
}
