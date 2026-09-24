import CipherCore
import CipherDesign
import Foundation

// The messaging ViewModels talk to Core through these narrow protocols instead of the concrete use
// case structs. Core's use cases adopt them retroactively below, so production wiring is a one-liner
// while previews and the fakes in `Data/Mocks/Messaging` can stand in without any crypto or network.

/// Sends and retries outgoing messages (`SendMessageUseCase`).
protocol MessageSending: Sendable {
    func execute(conversationId: ConversationID, payload: MessagePayload, expiresAt: Date?) async throws -> Message
    func retry(messageId: MessageID) async throws -> Message
}

/// Live message list of one conversation (`ObserveConversationUseCase`).
protocol ConversationObserving: Sendable {
    func execute(conversationId: ConversationID) async -> AsyncStream<[Message]>
}

/// Live inbox (`ObserveConversationsUseCase`).
protocol ConversationsObserving: Sendable {
    func execute() async -> AsyncStream<[Conversation]>
}

/// Marks a conversation read locally and emits the read receipt (`MarkConversationReadUseCase`).
protocol ConversationReadMarking: Sendable {
    func execute(conversationId: ConversationID) async throws -> [MessageID]
}

/// Username lookup, key pinning and conversation creation (`StartConversationUseCase`).
protocol ConversationStarting: Sendable {
    func execute(username: String) async throws -> Conversation
}

/// Pulls relay history into the local store (`SyncConversationUseCase`).
protocol ConversationSyncing: Sendable {
    func execute(conversationId: ConversationID) async throws -> [Message]
}

/// Records an out-of-band fingerprint comparison (`VerifyContactUseCase`).
protocol ContactVerifying: Sendable {
    func execute(userId: UserID) async throws -> Contact
}

/// Ephemeral typing signals in both directions. The outgoing side maps onto
/// `ClientEvent.typingStart/typingStop`; the incoming stream is fed from `RealtimeEffect.typing`.
protocol TypingSignaller: Sendable {
    func setTyping(_ isTyping: Bool, in conversationId: ConversationID) async
    func incomingTyping(in conversationId: ConversationID) async -> AsyncStream<TypingSignal>
}

/// Supplies the raw wire envelope a message was carried in, exactly as the relay stored it, for the
/// Server's-Eye view. Persistence keeps the envelope bytes next to the decrypted content.
protocol EnvelopeProviding: Sendable {
    func envelope(for messageId: MessageID) async throws -> Envelope?
}

/// Scans a draft for secrets worth sending as view-once. Runs off the main actor; the ViewModel only
/// publishes the most severe kind found. The Core kind is used here (not CipherDesign's chip kind) so
/// the port stays free of presentation types; `SensitiveKindMapping` bridges the two.
protocol SensitiveContentDetecting: Sendable {
    func detect(in text: String) async -> SensitiveKind?
}

/// Everything the attachments feature needs to seal, upload and send one staged file.
struct AttachmentSendRequest: Hashable, Sendable {
    var staged: StagedAttachment
    var caption: String?
    var flags: MessageFlags
    var replyTo: MessageID?
    var conversationId: ConversationID
    var expiresAt: Date?
}

/// Uploads a staged attachment and sends the resulting message. Owned by the attachments feature;
/// the chat composer only stages the pick and hands it over here.
protocol AttachmentSending: Sendable {
    func send(_ request: AttachmentSendRequest) async throws -> Message
}

/// Production detector: the Core scanner already hops off the main actor, so this adapter only picks
/// the most severe finding, which is all the composer chip can show.
struct CoreSensitiveContentDetector: SensitiveContentDetecting {
    private let useCase: DetectSensitiveContentUseCase

    init(useCase: DetectSensitiveContentUseCase = DetectSensitiveContentUseCase()) {
        self.useCase = useCase
    }

    func detect(in text: String) async -> SensitiveKind? {
        let findings = await useCase.execute(text: text)
        return findings.max { rank($0.kind) < rank($1.kind) }?.kind
    }

    /// Bank details outrank a card, which outranks a password guess, which outranks a code that
    /// expires in minutes anyway: the chip shows the finding a person would most regret leaking.
    private func rank(_ kind: SensitiveKind) -> Int {
        switch kind {
        case .iban: 4
        case .cardNumber: 3
        case .password: 2
        case .oneTimeCode: 1
        }
    }
}

extension SendMessageUseCase: MessageSending {}
extension ObserveConversationUseCase: ConversationObserving {}
extension ObserveConversationsUseCase: ConversationsObserving {}
extension MarkConversationReadUseCase: ConversationReadMarking {}
extension StartConversationUseCase: ConversationStarting {}
extension SyncConversationUseCase: ConversationSyncing {}
extension VerifyContactUseCase: ContactVerifying {}
