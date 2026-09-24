import CipherCore
import Foundation

/// Everything the messaging features need for one signed-in account: the per-account repositories,
/// the account-bound gateways and the use cases assembled from them.
///
/// It is a value built once per session by `AppContainer.makeMessagingStack(for:)`, because every
/// repository is scoped to an account's own store: switching accounts must never reuse a counter,
/// a replay record or a pinned key from the previous one. Use cases are computed on demand so each
/// screen gets a fresh struct over the same shared ports.
struct MessagingStack: Sendable {
    let account: User
    let messages: any MessageRepository
    let conversations: any ConversationRepository
    let contacts: any ContactRepository
    let outbox: any OutboxRepository
    let replayGuard: any ReplayGuard
    let crypto: any MessageCryptoService
    let keyDirectory: any KeyDirectoryGateway
    let conversationGateway: any ConversationGateway
    let realtime: any RealtimeGateway
    let clock: any Clock

    init(
        account: User,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        outbox: any OutboxRepository,
        replayGuard: any ReplayGuard,
        crypto: any MessageCryptoService,
        keyDirectory: any KeyDirectoryGateway,
        conversationGateway: any ConversationGateway,
        realtime: any RealtimeGateway,
        clock: any Clock = SystemClock()
    ) {
        self.account = account
        self.messages = messages
        self.conversations = conversations
        self.contacts = contacts
        self.outbox = outbox
        self.replayGuard = replayGuard
        self.crypto = crypto
        self.keyDirectory = keyDirectory
        self.conversationGateway = conversationGateway
        self.realtime = realtime
        self.clock = clock
    }

    var sendMessage: SendMessageUseCase {
        SendMessageUseCase(
            currentUserId: account.id,
            messages: messages,
            conversations: conversations,
            outbox: outbox,
            crypto: crypto,
            gateway: conversationGateway,
            clock: clock
        )
    }

    var receiveEnvelope: ReceiveEnvelopeUseCase {
        ReceiveEnvelopeUseCase(
            currentUserId: account.id,
            contacts: contacts,
            keyDirectory: keyDirectory,
            messages: messages,
            conversations: conversations,
            crypto: crypto,
            replayGuard: replayGuard,
            clock: clock
        )
    }

    var startConversation: StartConversationUseCase {
        StartConversationUseCase(
            currentUserId: account.id,
            keyDirectory: keyDirectory,
            conversationGateway: conversationGateway,
            contacts: contacts,
            conversations: conversations,
            clock: clock
        )
    }

    var syncConversation: SyncConversationUseCase {
        SyncConversationUseCase(currentUserId: account.id, gateway: conversationGateway, messages: messages, receive: receiveEnvelope)
    }

    var observeConversation: ObserveConversationUseCase {
        ObserveConversationUseCase(messages: messages)
    }

    var observeConversations: ObserveConversationsUseCase {
        ObserveConversationsUseCase(conversations: conversations)
    }

    var markConversationRead: MarkConversationReadUseCase {
        MarkConversationReadUseCase(messages: messages, conversations: conversations, realtime: realtime, clock: clock)
    }

    var verifyContact: VerifyContactUseCase {
        VerifyContactUseCase(contacts: contacts, clock: clock)
    }

    var handleRealtimeEvent: HandleRealtimeEventUseCase {
        HandleRealtimeEventUseCase(
            receive: receiveEnvelope,
            messages: messages,
            conversations: conversations,
            contacts: contacts,
            realtime: realtime,
            clock: clock
        )
    }

    var flushOutbox: FlushOutboxUseCase {
        FlushOutboxUseCase(messages: messages, conversations: conversations, outbox: outbox, gateway: conversationGateway, clock: clock)
    }
}
