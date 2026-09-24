import Foundation

/// Downloads a sealed blob, checks it against the digest that travelled inside the ciphertext, and
/// only then decrypts it. The digest check runs first because a tampered blob must fail loudly
/// before any key touches it, and because it is cheaper than the AEAD on a 25 MB file.
public struct FetchAttachmentUseCase: Sendable {
    public typealias ProgressHandler = @Sendable (AttachmentDownloadPhase) -> Void

    private let blobs: any AttachmentBlobGateway
    private let crypto: any MessageCryptoService
    private let hasher: any BlobHashing

    public init(blobs: any AttachmentBlobGateway, crypto: any MessageCryptoService, hasher: any BlobHashing) {
        self.blobs = blobs
        self.crypto = crypto
        self.hasher = hasher
    }

    /// Returns the plaintext bytes. Runs on the cooperative pool, never the main actor, because both
    /// the digest and the decryption scale with the file size.
    public func execute(
        messageId: MessageID,
        attachment: Attachment,
        onProgress: @escaping ProgressHandler = { _ in }
    ) async throws -> Data {
        guard !attachment.sha256.isEmpty else {
            throw AttachmentError.uploadIncomplete(messageId)
        }
        onProgress(.downloading(fraction: 0))
        let sealed: Data
        do {
            sealed = try await blobs.download(blobId: attachment.blobId) { fraction in
                onProgress(.downloading(fraction: fraction))
            }
        } catch {
            onProgress(.failed)
            throw error
        }
        onProgress(.verifying)
        let hasher = hasher
        let digest = await BackgroundWork.run { () throws(Never) in hasher.sha256Hex(sealed) }
        guard digest == attachment.sha256.lowercased() else {
            onProgress(.failed)
            CoreLog.attachments.error("digest mismatch message=\(messageId.description, privacy: .public)")
            throw AttachmentError.digestMismatch
        }
        onProgress(.decrypting)
        let crypto = crypto
        let key = attachment.key
        do {
            let plaintext = try await BackgroundWork.run { () throws(CryptoError) in try crypto.openBlob(sealed, key: key) }
            onProgress(.completed)
            CoreLog.attachments.info(
                "attachment opened message=\(messageId.description, privacy: .public) bytes=\(plaintext.count, privacy: .public)"
            )
            return plaintext
        } catch {
            onProgress(.failed)
            throw AttachmentError.openingFailed(error)
        }
    }
}
