import Foundation

/// The AEAD associated data from PROTOCOL.md §4:
/// `utf8("cipher/v1|" + senderId + "|" + conversationId + "|" + recipientId + "|" + counter + "|" + timestampMillis)`.
/// Binding the routing fields into the ciphertext's authentication tag means the relay (or anyone)
/// cannot re-address, re-order or re-time an envelope without the recipient noticing. Lives in Core so
/// the crypto engine and the tests share one definition.
public enum AssociatedData {
    public static func canonical(
        version: Int = CipherCore.protocolVersion,
        senderId: UserID,
        conversationId: ConversationID,
        recipientId: UserID,
        counter: UInt64,
        timestampMillis: Int64
    ) -> Data {
        let canonical = "cipher/v\(version)|\(senderId)|\(conversationId)|\(recipientId)|\(counter)|\(timestampMillis)"
        return Data(canonical.utf8)
    }

    public static func canonical(for header: EnvelopeHeader, version: Int = CipherCore.protocolVersion) -> Data {
        canonical(
            version: version,
            senderId: header.senderId,
            conversationId: header.conversationId,
            recipientId: header.recipientId,
            counter: header.counter,
            timestampMillis: header.timestampMillis
        )
    }

    /// Uses the envelope's own version so a v2 envelope is authenticated under its own label.
    public static func canonical(for envelope: Envelope) -> Data {
        canonical(for: envelope.header, version: envelope.version)
    }
}
