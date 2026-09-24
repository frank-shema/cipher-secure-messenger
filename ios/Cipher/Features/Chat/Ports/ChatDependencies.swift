import CipherCore
import Foundation

/// Everything `ChatViewModel` needs, gathered so the composition root builds it in one place and
/// previews can swap every port for the in-memory fakes.
struct ChatDependencies: Sendable {
    var currentUserId: UserID
    var observeMessages: any ConversationObserving
    var sender: any MessageSending
    var markRead: any ConversationReadMarking
    var messages: any MessageRepository
    var conversations: any ConversationRepository
    var contacts: any ContactRepository
    var typing: any TypingSignaller
    var envelopes: any EnvelopeProviding
    var sensitiveDetector: any SensitiveContentDetecting
    /// Nil disables attachment sending in the composer (the picks still fire their callbacks).
    var attachments: (any AttachmentSending)?
    /// Injected time source so previews can freeze "now" for capsules and countdowns.
    var now: @Sendable () -> Date

    init(
        currentUserId: UserID,
        observeMessages: any ConversationObserving,
        sender: any MessageSending,
        markRead: any ConversationReadMarking,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        typing: any TypingSignaller,
        envelopes: any EnvelopeProviding,
        sensitiveDetector: any SensitiveContentDetecting,
        attachments: (any AttachmentSending)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.currentUserId = currentUserId
        self.observeMessages = observeMessages
        self.sender = sender
        self.markRead = markRead
        self.messages = messages
        self.conversations = conversations
        self.contacts = contacts
        self.typing = typing
        self.envelopes = envelopes
        self.sensitiveDetector = sensitiveDetector
        self.attachments = attachments
        self.now = now
    }
}

/// Navigation the chat screen asks its host to perform. Closures rather than a Router dependency keep
/// the feature testable and let the app decide how each destination is presented.
struct ChatRoutes {
    var onVerify: @MainActor (UserID) -> Void
    var onOpenAttachment: @MainActor (MessageID) -> Void

    init(
        onVerify: @escaping @MainActor (UserID) -> Void = { _ in },
        onOpenAttachment: @escaping @MainActor (MessageID) -> Void = { _ in }
    ) {
        self.onVerify = onVerify
        self.onOpenAttachment = onOpenAttachment
    }
}

/// A file or photo the attachments feature has staged in the composer but not yet uploaded.
struct StagedAttachment: Hashable, Sendable, Identifiable {
    var id: UUID
    var filename: String
    var mimeType: String
    var size: Int
    /// Small preview for the composer; nil for non-image files.
    var previewImageData: Data?

    init(id: UUID = UUID(), filename: String, mimeType: String, size: Int, previewImageData: Data? = nil) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.previewImageData = previewImageData
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
}
