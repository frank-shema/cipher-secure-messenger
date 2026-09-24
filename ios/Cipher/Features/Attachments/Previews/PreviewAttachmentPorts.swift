import CipherCore
import Foundation

/// In-memory relay for previews: blobs live in a dictionary and transfers tick through a few
/// progress steps so rings animate.
actor PreviewBlobGateway: AttachmentBlobGateway {
    private var blobs: [BlobID: Data] = [:]
    private let stepDelay: Duration

    init(stepDelay: Duration = .milliseconds(120)) {
        self.stepDelay = stepDelay
    }

    func seed(_ data: Data, as blobId: BlobID) {
        blobs[blobId] = data
    }

    func upload(
        _ sealedBlob: Data,
        conversationId: ConversationID,
        expiresAt: Date?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> BlobID {
        try await tick(onProgress)
        let id = BlobID()
        blobs[id] = sealedBlob
        return id
    }

    func download(blobId: BlobID, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        guard let data = blobs[blobId] else { throw CipherCoreError.messageNotFound(MessageID()) }
        try await tick(onProgress)
        return data
    }

    private func tick(_ onProgress: @Sendable (Double) -> Void) async throws {
        for step in 1...8 {
            try await Task.sleep(for: stepDelay)
            onProgress(Double(step) / 8)
        }
    }
}

/// Stand-in `MessageCryptoService` for previews: blobs are framed, not encrypted, and envelopes are
/// noise. Never used outside `#Preview`.
struct PreviewAttachmentCrypto: MessageCryptoService {
    private static let nonceLength = 12
    private static let tagLength = 16

    func seal(payload: MessagePayload, for recipient: PublicKeyBundle, header: EnvelopeHeader) async throws(CryptoError) -> Envelope {
        Envelope(
            id: header.id,
            conversationId: header.conversationId,
            senderId: header.senderId,
            recipientId: header.recipientId,
            counter: header.counter,
            timestamp: header.timestampMillis,
            ciphertext: PreviewEnvelopeProvider.noise(seed: header.id.description, count: 96),
            signature: PreviewEnvelopeProvider.noise(seed: "sig|\(header.id)", count: 64),
            expiresAt: header.expiresAtMillis
        )
    }

    func open(_ envelope: Envelope, peer: PublicKeyBundle, myUserId: UserID) async throws(CryptoError) -> MessagePayload {
        throw .decryptionFailed
    }

    func attachmentKey() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    }

    func sealBlob(_ data: Data, key: Data) throws(CryptoError) -> Data {
        guard key.count == 32 else { throw .keyLength(expected: 32, actual: key.count) }
        return Data(repeating: 0x4E, count: Self.nonceLength) + data + Data(repeating: 0x54, count: Self.tagLength)
    }

    func openBlob(_ data: Data, key: Data) throws(CryptoError) -> Data {
        guard key.count == 32 else { throw .keyLength(expected: 32, actual: key.count) }
        guard data.count >= Self.nonceLength + Self.tagLength else { throw .decryptionFailed }
        return data.dropFirst(Self.nonceLength).dropLast(Self.tagLength)
    }

    func fingerprint(mine: PublicKeyBundle, theirs: PublicKeyBundle) -> SafetyFingerprint {
        SafetyFingerprint(emoji: Array(repeating: "🔒", count: 8), hex: String(repeating: "0", count: 64))
    }
}

actor PreviewOutbox: OutboxRepository {
    private var items: [MessageID: OutboxItem] = [:]

    func enqueue(_ item: OutboxItem) async throws { items[item.messageId] = item }
    func item(messageId: MessageID) async throws -> OutboxItem? { items[messageId] }
    func pending() async throws -> [OutboxItem] { items.values.sorted { $0.enqueuedAt < $1.enqueuedAt } }
    func remove(messageId: MessageID) async throws { items.removeValue(forKey: messageId) }
    func markAttempt(messageId: MessageID, error: String?, at: Date) async throws {
        items[messageId]?.attempts += 1
        items[messageId]?.lastError = error
    }
}

/// Acknowledges every send immediately.
struct PreviewConversationGateway: ConversationGateway {
    func createOrGet(participantId: UserID) async throws -> RemoteConversation {
        RemoteConversation(id: ConversationID(), participants: [], createdAt: Date(), lastMessageAt: nil)
    }

    func list() async throws -> [RemoteConversation] { [] }

    func fetchMessages(conversationId: ConversationID, before: Date?, limit: Int) async throws -> MessagePage {
        MessagePage(items: [], hasMore: false)
    }

    func send(_ envelope: Envelope) async throws -> MessageAck {
        MessageAck(id: envelope.id, status: .sent, createdAt: Date())
    }
}

actor PreviewViewOnceMarker: ViewOnceMarking {
    private var viewed: [MessageID: Date] = [:]

    func markViewed(messageId: MessageID) async throws -> Bool {
        guard viewed[messageId] == nil else { return false }
        viewed[messageId] = Date()
        return true
    }

    func viewedAt(messageId: MessageID) async throws -> Date? { viewed[messageId] }
}
