import CipherCore
import CipherNetworking
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
    /// Raw wire envelopes for the Server's-Eye view.
    let envelopes: any EnvelopeProviding
    /// Where the per-conversation disappearing timer is kept.
    let disappearingTimers: any DisappearingTimerStoring
    /// Expiry sweeps, when the backing store can find expired rows; nil for stores that cannot.
    let expiredMessages: (any ExpiredMessageDeleting)?
    /// Durable home for incoming raw envelopes; nil when the store keeps none.
    let rawEnvelopes: (any RawEnvelopeRecording)?
    /// Relay attachment routes; nil for stacks with no blob transport (previews, decoy).
    let attachmentGateway: (any AttachmentGateway)?
    /// Durable "opened once" record for view-once media; nil where nothing persists.
    let viewOnce: (any ViewOnceMarking)?

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
        clock: any Clock = SystemClock(),
        envelopes: (any EnvelopeProviding)? = nil,
        disappearingTimers: (any DisappearingTimerStoring)? = nil,
        expiredMessages: (any ExpiredMessageDeleting)? = nil,
        rawEnvelopes: (any RawEnvelopeRecording)? = nil,
        attachmentGateway: (any AttachmentGateway)? = nil,
        viewOnce: (any ViewOnceMarking)? = nil
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
        self.envelopes = envelopes ?? OutboxEnvelopeProvider(outbox: outbox)
        self.disappearingTimers = disappearingTimers ?? ConversationRepositoryTimerStore(conversations: conversations)
        self.expiredMessages = expiredMessages
        self.rawEnvelopes = rawEnvelopes
        self.attachmentGateway = attachmentGateway
        self.viewOnce = viewOnce
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

    var evaluateTrust: EvaluateTrustUseCase {
        EvaluateTrustUseCase(conversations: conversations, preferences: AlwaysOnMetadataStripping(), clock: clock)
    }

    var changeDisappearingTimer: ChangeDisappearingTimerUseCase {
        let clock = clock
        return ChangeDisappearingTimerUseCase(store: disappearingTimers, sender: sendMessage, now: { clock.now() })
    }
}
