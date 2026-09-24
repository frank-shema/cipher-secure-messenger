import CipherCore
import Foundation

/// Every port the attachments feature needs for one signed-in account. Built from the
/// `MessagingStack` plus the two attachment-specific adapters.
struct AttachmentPorts: Sendable {
    var accountId: UserID
    var messages: any MessageRepository
    var conversations: any ConversationRepository
    var outbox: any OutboxRepository
    var crypto: any MessageCryptoService
    var conversationGateway: any ConversationGateway
    var blobs: any AttachmentBlobGateway
    var viewOnce: any ViewOnceMarking
    var hasher: any BlobHashing
    var clock: any Clock

    init(
        accountId: UserID,
        messages: any MessageRepository,
        conversations: any ConversationRepository,
        outbox: any OutboxRepository,
        crypto: any MessageCryptoService,
        conversationGateway: any ConversationGateway,
        blobs: any AttachmentBlobGateway,
        viewOnce: any ViewOnceMarking,
        hasher: any BlobHashing = CryptoKitBlobHasher(),
        clock: any Clock = SystemClock()
    ) {
        self.accountId = accountId
        self.messages = messages
        self.conversations = conversations
        self.outbox = outbox
        self.crypto = crypto
        self.conversationGateway = conversationGateway
        self.blobs = blobs
        self.viewOnce = viewOnce
        self.hasher = hasher
        self.clock = clock
    }

    /// Production wiring: everything but the blob gateway and the view-once marker comes from the stack.
    init(stack: MessagingStack, blobs: any AttachmentBlobGateway, viewOnce: any ViewOnceMarking) {
        self.init(
            accountId: stack.account.id,
            messages: stack.messages,
            conversations: stack.conversations,
            outbox: stack.outbox,
            crypto: stack.crypto,
            conversationGateway: stack.conversationGateway,
            blobs: blobs,
            viewOnce: viewOnce,
            clock: stack.clock
        )
    }
}
