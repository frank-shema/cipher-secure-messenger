import Foundation

/// Ephemeral typing state for the chat header; never persisted.
public struct TypingSignal: Hashable, Sendable {
    public var conversationId: ConversationID
    public var userId: UserID
    public var isTyping: Bool

    public init(conversationId: ConversationID, userId: UserID, isTyping: Bool) {
        self.conversationId = conversationId
        self.userId = userId
        self.isTyping = isTyping
    }
}

/// What a realtime event did, so the app layer can react (haptics, toasts) without re-deriving it.
public enum RealtimeEffect: Hashable, Sendable {
    case none
    case messageReceived(Message)
    case statusUpdated(conversationId: ConversationID, messageIds: [MessageID], status: MessageStatus)
    case typing(TypingSignal)
    case presenceUpdated(userId: UserID, presence: Presence)
    case keyChanged(userId: UserID, trust: TrustState)
    case serverError(code: String, message: String)
}

/// Routes every server event to the store it affects. `message.new` runs `ReceiveEnvelopeUseCase` and
/// acknowledges over the socket afterwards, so an envelope is only ever acked once it is persisted.
public struct HandleRealtimeEventUseCase: Sendable {
    private let receive: ReceiveEnvelopeUseCase
    private let messages: any MessageRepository
    private let conversations: any ConversationRepository
    private let contacts: any ContactRepository
    private let realtime: any RealtimeGateway
    private let clock: any Clock

    public init(
        receive: ReceiveEnvelopeUseCase,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        realtime: any RealtimeGateway,
        clock: any Clock = SystemClock()
    ) {
        self.receive = receive
        self.messages = messages
        self.conversations = conversations
        self.contacts = contacts
        self.realtime = realtime
        self.clock = clock
    }

    public func execute(_ event: ServerEvent) async throws -> RealtimeEffect {
        switch event {
        case .messageNew(let stored):
            return try await handleNewMessage(stored)
        case .receiptDelivered(let receipt):
            return try await apply(receipt, status: .delivered)
        case .receiptRead(let receipt):
            return try await apply(receipt, status: .read)
        case .typingStart(let conversationId, let userId):
            return .typing(TypingSignal(conversationId: conversationId, userId: userId, isTyping: true))
        case .typingStop(let conversationId, let userId):
            return .typing(TypingSignal(conversationId: conversationId, userId: userId, isTyping: false))
        case .presenceUpdate(let userId, let presence):
            try await contacts.updatePresence(userId: userId, presence: presence)
            return .presenceUpdated(userId: userId, presence: presence)
        case .keyChanged(let bundle):
            return try await handleKeyChange(bundle)
        case .error(let code, let message, _):
            CoreLog.useCases.error("relay error \(code, privacy: .public)")
            return .serverError(code: code, message: message)
        case .pong:
            return .none
        }
    }

    private func handleNewMessage(_ stored: StoredEnvelope) async throws -> RealtimeEffect {
        let message = try await receive.execute(stored)
        do {
            try await realtime.send(.messageAck(messageIds: [stored.id]))
        } catch {
            CoreLog.useCases.notice("ack for \(stored.id.description, privacy: .public) not sent; relay will re-push")
        }
        return .messageReceived(message)
    }

    private func apply(_ receipt: Receipt, status: MessageStatus) async throws -> RealtimeEffect {
        try await messages.updateStatus(ids: receipt.messageIds, status: status, at: receipt.at)
        if let conversation = try await conversations.fetch(id: receipt.conversationId),
           let last = conversation.lastMessage,
           receipt.messageIds.contains(last.id),
           let refreshed = try await messages.fetch(id: last.id) {
            try await conversations.updateLastMessage(conversationId: conversation.id, message: refreshed)
        }
        return .statusUpdated(conversationId: receipt.conversationId, messageIds: receipt.messageIds, status: status)
    }

    /// Re-pins the announced keys and flags the contact when the material actually changed. Unknown
    /// users are ignored: without a pinned identity there is nothing to compare against.
    private func handleKeyChange(_ bundle: PublicKeyBundle) async throws -> RealtimeEffect {
        guard bundle.hasValidKeyLengths else {
            CoreLog.useCases.error("ignoring key.changed with invalid key lengths for \(bundle.userId.description, privacy: .public)")
            return .none
        }
        guard let contact = try await contacts.fetch(userId: bundle.userId) else {
            return .none
        }
        try await contacts.setKeys(userId: bundle.userId, keys: bundle)
        guard let previous = contact.keys, !previous.hasSameKeyMaterial(as: bundle) else {
            return .keyChanged(userId: bundle.userId, trust: contact.trust)
        }
        let trust = TrustState.keyChanged(previousVersion: previous.version, at: clock.now())
        try await contacts.setTrust(userId: bundle.userId, trust: trust)
        CoreLog.useCases.warning("key material changed for user \(bundle.userId.description, privacy: .public)")
        return .keyChanged(userId: bundle.userId, trust: trust)
    }
}
