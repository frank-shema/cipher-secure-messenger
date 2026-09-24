import CipherCore
import Foundation

/// Resolves a message's attachment to a local file: cache hit, or download → verify → decrypt →
/// write. Progress lands in the `AttachmentTransferCenter` under the message id.
struct AttachmentDownloader: Sendable {
    private let fetch: FetchAttachmentUseCase
    private let cache: AttachmentCache
    private let transfers: AttachmentTransferCenter

    init(fetch: FetchAttachmentUseCase, cache: AttachmentCache, transfers: AttachmentTransferCenter) {
        self.fetch = fetch
        self.cache = cache
        self.transfers = transfers
    }

    func localFile(for message: Message) async throws -> URL {
        guard case .attachment(let attachment, _) = message.content else {
            throw AttachmentError.notAnAttachment(message.id)
        }
        if let cached = cache.existingFile(for: message.id) {
            AttachmentsLog.transfer.debug("cache hit message=\(message.id.description, privacy: .public)")
            return cached
        }
        let plaintext = try await fetch.execute(
            messageId: message.id,
            attachment: attachment,
            onProgress: transfers.downloadReporter(for: message.id)
        )
        return try cache.store(plaintext, messageId: message.id, filename: attachment.filename)
    }

    func purge(messageId: MessageID) {
        cache.remove(messageId: messageId)
    }
}
