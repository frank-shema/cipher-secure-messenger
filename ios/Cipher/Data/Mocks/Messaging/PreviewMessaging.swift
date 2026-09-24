import CipherCore
import CipherDesign
import Foundation

/// One-call wiring of the messaging fakes for `#Preview`s. Each call builds an isolated store so
/// previews never leak state into one another.
@MainActor
enum PreviewMessaging {
    /// A frozen clock keeps "last seen", countdowns and the sealed capsule stable between renders.
    static let frozenNow = Date()

    struct Bundle {
        let store: PreviewMessagingStore
        let typing: PreviewTypingSignaller
        let chat: ChatDependencies
        let list: ConversationListDependencies
        let conversations: [Conversation]
    }

    static func bundle(
        now: Date = frozenNow,
        echoes: Bool = true,
        sensitive: SensitiveKind? = nil,
        seeded: Bool = true
    ) -> Bundle {
        let store = seeded ? PreviewMessagingStore.seeded(now: now) : PreviewMessagingStore()
        let typing = PreviewTypingSignaller()
        let sender = PreviewMessageSender(store: store, typing: typing, currentUserId: MessagingFixtures.me.id, echoes: echoes)
        let clock: @Sendable () -> Date = { Date() }
        let chat = ChatDependencies(
            currentUserId: MessagingFixtures.me.id,
            observeMessages: PreviewConversationObserver(store: store),
            sender: sender,
            markRead: PreviewReadMarker(store: store),
            messages: store,
            conversations: store,
            contacts: store,
            typing: typing,
            envelopes: PreviewEnvelopeProvider(store: store),
            sensitiveDetector: PreviewSensitiveDetector(fixed: sensitive),
            attachments: nil,
            now: clock
        )
        let list = ConversationListDependencies(
            observeConversations: PreviewConversationsObserver(store: store),
            markRead: PreviewReadMarker(store: store),
            sync: PreviewConversationSyncer(),
            start: PreviewConversationStarter(store: store),
            conversations: store,
            now: clock
        )
        return Bundle(store: store, typing: typing, chat: chat, list: list,
                      conversations: seeded ? MessagingFixtures.conversations(now: now) : [])
    }

    /// The Bob thread, fully populated, with the echo companion answering sends.
    static func chatViewModel(echoes: Bool = true, sensitive: SensitiveKind? = nil) -> ChatViewModel {
        let bundle = bundle(echoes: echoes, sensitive: sensitive)
        return ChatViewModel(conversation: sampleConversation, dependencies: bundle.chat)
    }

    static func conversationListViewModel() -> ConversationListViewModel {
        ConversationListViewModel(dependencies: bundle().list)
    }

    static var sampleMessages: [Message] { MessagingFixtures.bobThread(now: frozenNow) }
    static var sampleConversation: Conversation { MessagingFixtures.bobConversation(now: frozenNow) }
}

struct PreviewConversationObserver: ConversationObserving {
    let store: PreviewMessagingStore

    func execute(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        await store.observe(conversationId: conversationId)
    }
}

struct PreviewConversationsObserver: ConversationsObserving {
    let store: PreviewMessagingStore

    func execute() async -> AsyncStream<[Conversation]> {
        await store.observeAll()
    }
}
