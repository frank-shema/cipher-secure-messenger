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
        let chat = ChatDependencies(
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
        self.surface = MessagingSurface(
            account: stack.account,
            list: list,
            chat: chat,
            verify: VerifyDependencies(stack: stack, identityKeys: identityKeys),
            isDecoy: false
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
}
