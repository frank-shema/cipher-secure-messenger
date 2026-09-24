import Foundation

/// Failures specific to sending or opening attachments. Transport errors keep their own types.
public enum AttachmentError: Error, LocalizedError, Hashable, Sendable {
    /// The plaintext would seal to more than the relay accepts.
    case tooLarge(bytes: Int, limit: Int)
    /// The embedded thumbnail exceeds the protocol ceiling; the sender must shrink it first.
    case thumbnailTooLarge(bytes: Int)
    /// The downloaded blob's digest does not match the one sealed inside the message.
    case digestMismatch
    /// The bytes for a staged attachment are no longer available (the app was relaunched mid-send).
    case draftUnavailable
    /// The message exists locally but its blob never reached the relay, so there is nothing to resend.
    case uploadIncomplete(MessageID)
    /// The message is not an attachment, or could not be found.
    case notAnAttachment(MessageID)
    case sealingFailed(CryptoError)
    case openingFailed(CryptoError)

    public var errorDescription: String? {
        switch self {
        case .tooLarge:
            CoreStrings.localized("error.attachment.tooLarge", default: "This file is too large to send. The limit is 25 MB.")
        case .thumbnailTooLarge:
            CoreStrings.localized("error.attachment.thumbnailTooLarge", default: "The preview image could not be prepared.")
        case .digestMismatch:
            CoreStrings.localized(
                "error.attachment.digestMismatch",
                default: "The attachment failed its integrity check and was not opened."
            )
        case .draftUnavailable:
            CoreStrings.localized(
                "error.attachment.draftUnavailable",
                default: "The attachment is no longer available. Please pick it again."
            )
        case .uploadIncomplete:
            CoreStrings.localized(
                "error.attachment.uploadIncomplete",
                default: "This attachment never finished uploading. Please send it again."
            )
        case .notAnAttachment:
            CoreStrings.localized("error.attachment.notAnAttachment", default: "This message has no attachment.")
        case .sealingFailed:
            CoreStrings.localized("error.attachment.sealingFailed", default: "The attachment could not be encrypted.")
        case .openingFailed:
            CoreStrings.localized("error.attachment.openingFailed", default: "The attachment could not be decrypted.")
        }
    }
}
