import Foundation

/// Why an envelope could not be turned into readable content. Persisted with the message so the UI
/// can explain the warning, and so a repeated failure is visible rather than silently dropped.
public enum TamperReason: String, Hashable, Codable, Sendable, CaseIterable {
    case invalidSignature
    case replayed
    case decryptionFailed
    case unknownSender
    case malformedPayload
}

/// Decrypted, validated content of a message, or the reason it could not be trusted.
public enum MessageContent: Hashable, Codable, Sendable {
    case text(String)
    case attachment(Attachment, caption: String?)
    case reaction(Reaction)
    case system(SystemEvent)
    case tampered(TamperReason)

    public var isTampered: Bool {
        tamperReason != nil
    }

    public var tamperReason: TamperReason? {
        if case .tampered(let reason) = self { return reason }
        return nil
    }

    public var isReaction: Bool {
        if case .reaction = self { return true }
        return false
    }
}
