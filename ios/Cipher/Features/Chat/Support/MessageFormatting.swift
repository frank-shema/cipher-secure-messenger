import CipherCore
import CipherDesign
import Foundation

/// Text derived from messages for lists, quotes and accessibility. Kept out of the views so the inbox
/// preview, the reply quote and VoiceOver labels can never disagree about how a message reads.
enum MessageFormatting {
    /// One-line summary of a message. Attachments and tampered messages are described rather than
    /// exposed, because the preview appears outside the conversation.
    static func preview(for message: Message?) -> String {
        guard let message else {
            return String(localized: "conversations.preview.empty", defaultValue: "No messages yet")
        }
        if message.flags.unlockAt.map({ $0 > Date() }) == true, message.direction == .incoming {
            return String(localized: "conversations.preview.sealed", defaultValue: "Sealed time capsule")
        }
        if message.flags.whisper, message.direction == .incoming {
            return String(localized: "conversations.preview.whisper", defaultValue: "Whisper, hold to read")
        }
        switch message.content {
        case .text(let body):
            return body.replacingOccurrences(of: "\n", with: " ")
        case .attachment(let attachment, let caption):
            if let caption, !caption.isEmpty { return caption }
            return attachment.mimeType.hasPrefix("image/")
                ? String(localized: "conversations.preview.photo", defaultValue: "Encrypted photo")
                : String(localized: "conversations.preview.attachment", defaultValue: "Encrypted attachment")
        case .reaction(let reaction):
            return String(localized: "conversations.preview.reaction", defaultValue: "Reacted \(reaction.emoji)")
        case .system(let event):
            return systemText(for: event.kind, contactName: nil)
        case .tampered:
            return String(localized: "conversations.preview.tampered", defaultValue: "Message could not be verified")
        }
    }

    /// Human explanation of a system event, phrased around the other participant when known.
    static func systemText(for kind: SystemEvent.Kind, contactName: String?) -> String {
        let name = contactName ?? String(localized: "chat.system.contactFallback", defaultValue: "Your contact")
        switch kind {
        case .screenshotTaken:
            return String(localized: "chat.system.screenshotTaken", defaultValue: "\(name) took a screenshot")
        case .viewOnceOpened:
            return String(localized: "chat.system.viewOnceOpened", defaultValue: "\(name) opened your view-once message")
        case .disappearingChanged:
            return String(localized: "chat.system.disappearingChanged", defaultValue: "Disappearing message timer changed")
        case .keyVerified:
            return String(localized: "chat.system.keyVerified", defaultValue: "Safety keys with \(name) verified")
        }
    }

    /// Why a message is shown with a warning instead of content.
    static func tamperExplanation(for reason: TamperReason) -> String {
        switch reason {
        case .invalidSignature:
            String(localized: "chat.tampered.invalidSignature", defaultValue: "The signature does not match the sender's pinned key.")
        case .replayed:
            String(localized: "chat.tampered.replayed", defaultValue: "This message was delivered twice; the duplicate was ignored.")
        case .decryptionFailed:
            String(localized: "chat.tampered.decryptionFailed", defaultValue: "The content could not be decrypted with the shared key.")
        case .unknownSender:
            String(localized: "chat.tampered.unknownSender", defaultValue: "The sender's keys could not be found.")
        case .malformedPayload:
            String(localized: "chat.tampered.malformedPayload", defaultValue: "The decrypted content was not a valid message.")
        }
    }

    /// Short time for bubble metadata, honouring the locale's 12/24-hour setting.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Compact relative timestamp for inbox rows: time today, weekday this week, date otherwise.
    static func inboxTimestamp(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return time(date)
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: now), date > weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Byte count for file bubbles.
    static func fileSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// The relay-visible fields of an envelope, in the order the Server's-Eye panel shows them. Only
    /// routing metadata and opaque bytes appear here: no text, no filename, nothing from inside.
    static func serverFields(for envelope: Envelope) -> [(label: String, value: String)] {
        let ciphertext = envelope.ciphertext.base64EncodedString()
        let signature = envelope.signature.base64EncodedString()
        return [
            (String(localized: "serversEye.field.id", defaultValue: "id"), envelope.id.description),
            (String(localized: "serversEye.field.counter", defaultValue: "counter"), String(envelope.counter)),
            (String(localized: "serversEye.field.ciphertext", defaultValue: "ciphertext"),
             truncated(ciphertext, bytes: envelope.ciphertext.count)),
            (String(localized: "serversEye.field.signature", defaultValue: "signature"), signature),
            (String(localized: "serversEye.field.expiresAt", defaultValue: "expiresAt"), envelope.expiresAt.map(String.init) ?? "null"),
            (String(localized: "serversEye.field.createdAt", defaultValue: "timestamp"), String(envelope.timestamp))
        ]
    }

    private static func truncated(_ base64: String, bytes: Int) -> String {
        guard base64.count > 48 else { return base64 }
        let head = base64.prefix(32)
        let tail = base64.suffix(12)
        return "\(head)…\(tail) (\(bytes) B)"
    }
}

extension TrustState {
    /// Shield rendering of a trust state: verified is calm, a key change shouts.
    var shieldState: ShieldState {
        switch self {
        case .unverified: .unverified
        case .verified: .verified
        case .keyChanged: .warning
        }
    }

    /// Fill level for `TrustRing`. Unverified sits in the warning band on purpose: it is the state
    /// most people never leave, and the ring should nudge them toward verifying.
    var ringScore: Double {
        switch self {
        case .verified: 1
        case .unverified: 0.5
        case .keyChanged: 0.15
        }
    }
}

extension MessageStatus {
    var bubbleStatus: BubbleStatus {
        switch self {
        case .sending: .sending
        case .sent: .sent
        case .delivered: .delivered
        case .read: .read
        case .failed: .failed
        }
    }
}
