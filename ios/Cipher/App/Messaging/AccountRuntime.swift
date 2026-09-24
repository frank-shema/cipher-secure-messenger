import CipherCore
import CipherDesign
import Foundation

/// The live objects behind one signed-in account: the messaging stack, the socket pump, the expiry
/// sweeper and the adapters that turn Core ports into what the screens consume. Built once per
/// session by the container, driven by `MessagingCoordinator`.
@MainActor
final class AccountRuntime: ActiveMessaging {
    let stack: MessagingStack
    let surface: MessagingSurface
    /// Sealing, uploads, view-once and the protected cache for this account; nil when the cache
    /// directory could not be created (text messaging keeps working).
    let attachments: AttachmentsFeature?
    var onConnectionChange: @MainActor (RealtimeConnectionState) -> Void = { _ in } {
        didSet { pump.onConnectionChange = onConnectionChange }
    }

    private let pump: RealtimeEventPump
    private let typing: RealtimeTypingSignaller
    private let expiry: ExpiryScheduler?
    private var isStarted = false

    init(
        stack: MessagingStack,
        identityKeys: any IdentityKeyStore,
        haptics: any HapticEngine,
        toasts: ToastCenter,
        defaults: UserDefaults
    ) {
        let clock = stack.clock
        let now: @Sendable () -> Date = { clock.now() }
        let typing = RealtimeTypingSignaller(realtime: stack.realtime)
        let timerSync = DisappearingTimerSync(store: stack.disappearingTimers)
        let expiry = stack.expiredMessages.map { ExpiryScheduler(deleter: $0, clock: clock) }
        let sensitiveGuard = SensitiveContentGuard(
            configuration: .immediate,
            isEnabled: SensitiveGuardPreferences(defaults: defaults).reader
        )
        let attachments = Self.makeAttachments(stack: stack, toasts: toasts, haptics: haptics)
        var chat = ChatDependencies(
            currentUserId: stack.account.id,
            observeMessages: stack.observeConversation,
            sender: stack.sendMessage,
            markRead: stack.markConversationRead,
            messages: stack.messages,
            conversations: stack.conversations,
            contacts: stack.contacts,
            typing: typing,
            envelopes: stack.envelopes,
            sensitiveDetector: sensitiveGuard,
            attachments: nil,
            changeTimer: stack.changeDisappearingTimer,
            trust: stack.evaluateTrust,
            expiry: expiry,
            now: now
        )
        if let attachments {
            chat = chat.withAttachments(attachments)
        }
        let list = ConversationListDependencies(
            observeConversations: stack.observeConversations,
            markRead: stack.markConversationRead,
            sync: stack.syncConversation,
            start: stack.startConversation,
            conversations: stack.conversations,
            now: now
        )
        self.stack = stack
        self.typing = typing
        self.expiry = expiry
        self.attachments = attachments
        self.surface = MessagingSurface(
            account: stack.account,
            list: list,
            chat: chat,
            verify: VerifyDependencies(stack: stack, identityKeys: identityKeys),
            isDecoy: false,
            attachments: attachments
        )
        self.pump = RealtimeEventPump(stack: stack, typing: typing, timerSync: timerSync, haptics: haptics, toasts: toasts)
    }

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        pump.start()
        await expiry?.start()
        await stack.realtime.connect()
        AppLog.messaging.info("runtime started for \(self.stack.account.id.description, privacy: .public)")
    }

    func stop() async {
        pump.stop()
        await expiry?.stop()
        await typing.finishAll()
        await stack.realtime.disconnect()
        attachments?.removeCachedFiles()
        isStarted = false
        AppLog.messaging.info("runtime stopped")
    }

    func suspend() async {
        await stack.realtime.disconnect()
        await expiry?.applicationDidEnterBackground()
    }

    func resume() async {
        guard isStarted else {
            await start()
            return
        }
        await stack.realtime.connect()
        await expiry?.applicationDidBecomeActive()
    }

    /// Builds the attachments feature when the stack carries a blob transport and a view-once
    /// record. Returns nil, after logging, when the protected cache directory cannot be created,
    /// so text messaging still comes up.
    private static func makeAttachments(
        stack: MessagingStack,
        toasts: ToastCenter,
        haptics: any HapticEngine
    ) -> AttachmentsFeature? {
        guard let gateway = stack.attachmentGateway, let viewOnce = stack.viewOnce else { return nil }
        do {
            return try AttachmentsFeatureWiring.make(
                stack: stack,
                attachmentGateway: gateway,
                viewOnce: viewOnce,
                toasts: toasts,
                haptics: haptics
            )
        } catch {
            AppLog.messaging.error("attachments unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
