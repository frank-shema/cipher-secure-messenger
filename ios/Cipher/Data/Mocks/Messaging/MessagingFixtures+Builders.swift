import CipherCore
import Foundation
import UIKit

extension MessagingFixtures {
    /// One conversation between `me` and `peer`; every builder derives sender, recipient and
    /// direction from that pair so a fixture line only says what the message is.
    struct Thread {
        let id: ConversationID
        let peer: User

        func text(
            _ body: String,
            _ direction: MessageDirection,
            at sentAt: Date,
            counter: UInt64,
            status: MessageStatus,
            replyTo: MessageID? = nil,
            reactions: [String] = []
        ) -> Message {
            make(.text(body), direction, at: sentAt, counter: counter, status: status, replyTo: replyTo, reactions: reactions)
        }

        func photo(
            _ direction: MessageDirection,
            at sentAt: Date,
            counter: UInt64,
            status: MessageStatus,
            viewOnce: Bool = false
        ) -> Message {
            let id = messageId(direction, counter: counter)
            let attachment = Attachment(
                blobId: BlobID(MessagingFixtures.stableUUID("blob|\(id)")),
                key: Fixtures.syntheticKey(seed: id.description, salt: 0x77),
                sha256: String(repeating: "a1", count: 32), mimeType: "image/jpeg", filename: "IMG_2048.jpg",
                size: 184_320, width: 1_200, height: 900, thumbnail: MessagingFixtures.sampleThumbnail
            )
            var message = make(.attachment(attachment, caption: nil), direction, at: sentAt, counter: counter, status: status)
            message.flags.viewOnce = viewOnce
            return message
        }

        func file(_ direction: MessageDirection, at sentAt: Date, counter: UInt64, status: MessageStatus) -> Message {
            let id = messageId(direction, counter: counter)
            let attachment = Attachment(
                blobId: BlobID(MessagingFixtures.stableUUID("blob|\(id)")),
                key: Fixtures.syntheticKey(seed: id.description, salt: 0x78),
                sha256: String(repeating: "b2", count: 32), mimeType: "application/pdf", filename: "floor-plan-v3.pdf", size: 2_411_008
            )
            return make(.attachment(attachment, caption: "Second page is the interesting one"), direction,
                        at: sentAt, counter: counter, status: status)
        }

        func tampered(at sentAt: Date, counter: UInt64) -> Message {
            make(.tampered(.invalidSignature), .incoming, at: sentAt, counter: counter, status: .delivered)
        }

        func system(_ kind: SystemEvent.Kind, _ direction: MessageDirection, at sentAt: Date, counter: UInt64) -> Message {
            make(.system(SystemEvent(kind: kind)), direction, at: sentAt, counter: counter, status: .read)
        }

        /// Ids derive from (conversation, sender, counter) so the same fixture message has the same id
        /// on every render, which keeps reply quotes and reactions pointing at it.
        func messageId(_ direction: MessageDirection, counter: UInt64) -> MessageID {
            let sender = direction == .outgoing ? MessagingFixtures.me : peer
            return MessageID(MessagingFixtures.stableUUID("\(id)|\(sender.id)|\(counter)"))
        }

        private func make(
            _ content: MessageContent,
            _ direction: MessageDirection,
            at sentAt: Date,
            counter: UInt64,
            status: MessageStatus,
            replyTo: MessageID? = nil,
            reactions: [String] = []
        ) -> Message {
            let id = messageId(direction, counter: counter)
            let sender = direction == .outgoing ? MessagingFixtures.me : peer
            let recipient = direction == .outgoing ? peer : MessagingFixtures.me
            let acknowledged = status != .sending && status != .failed
            return Message(
                id: id, conversationId: self.id, senderId: sender.id, recipientId: recipient.id, direction: direction,
                content: content, flags: .none, replyToId: replyTo, counter: counter, sentAt: sentAt,
                serverCreatedAt: acknowledged ? sentAt.addingTimeInterval(0.2) : nil, status: status, expiresAt: nil,
                reactions: reactions.map { Reaction(targetId: id, emoji: $0) }
            )
        }
    }

    static func stableUUID(_ key: String) -> UUID {
        var high: UInt64 = 0xCBF2_9CE4_8422_2325
        var low: UInt64 = 0x8422_2325_CBF2_9CE4
        for byte in key.utf8 {
            high = (high ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            low = (low &+ UInt64(byte)) &* 0x9E37_79B9_7F4A_7C15
        }
        let hi = high.bigEndianBytes
        let lo = low.bigEndianBytes
        return UUID(uuid: (hi[0], hi[1], hi[2], hi[3], hi[4], hi[5], (hi[6] & 0x0F) | 0x40, hi[7],
                           (lo[0] & 0x3F) | 0x80, lo[1], lo[2], lo[3], lo[4], lo[5], lo[6], lo[7]))
    }

    /// A small rendered JPEG so photo bubbles show a real thumbnail instead of a placeholder.
    static let sampleThumbnail: Data? = {
        let size = CGSize(width: 240, height: 180)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor(red: 0.11, green: 0.36, blue: 0.42, alpha: 1).cgColor,
                          UIColor(red: 0.95, green: 0.62, blue: 0.29, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 150, y: 30, width: 46, height: 46)).fill()
            UIColor(white: 0.1, alpha: 0.55).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 130, width: size.width, height: 50)).fill()
        }
        return image.jpegData(compressionQuality: 0.7)
    }()
}

private extension UInt64 {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian) { Array($0) }
    }
}
