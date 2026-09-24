import CipherCore
import CryptoKit
import Foundation

/// The inbox shown after a duress unlock: a believable, fictional set of conversations that lives only
/// in memory and is regenerated from a per-account seed on every unlock, so it never reshuffles and
/// never touches the persistence store. Exposes the same dependency bundles the real inbox and chat use,
/// so `ConversationListView` and `ChatView` render it without knowing anything changed.
struct DecoyInboxProvider: Sendable {
    let localUserId: UserID
    let seed: UInt64
    /// Newest first, as the list sorts.
    let conversations: [Conversation]

    private let store: PreviewMessagingStore
    private let now: @Sendable () -> Date

    /// Generates the inbox off the main actor. `seed` defaults to a value derived from the account so the
    /// same person always sees the same decoy; pass one explicitly only for previews.
    static func make(
        localUserId: UserID,
        seed: UInt64? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> DecoyInboxProvider {
        let resolvedSeed = seed ?? Self.seed(for: localUserId)
        let generator = DecoyInboxGenerator(seed: resolvedSeed, localUserId: localUserId)
        let inbox = await Task.detached(priority: .userInitiated) {
            generator.generate(now: now())
        }.value
        let store = PreviewMessagingStore(
            conversations: inbox.conversations,
            contacts: inbox.conversations.map(\.contact),
            messages: inbox.messages.values.flatMap { $0 }
        )
        LockLog.decoy.info("decoy inbox ready conversations=\(inbox.conversations.count, privacy: .public)")
        return DecoyInboxProvider(localUserId: localUserId, seed: resolvedSeed, conversations: inbox.conversations, store: store, now: now)
    }

    /// Stable per account: SHA-256 over the user id folded to 64 bits. Not secret; a decoy that changes
    /// between unlocks would be the tell.
    static func seed(for userId: UserID) -> UInt64 {
        let digest = SHA256.hash(data: Data("cipher.decoy.v1|\(userId.description)".utf8))
        return digest.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    /// Drop-in replacement for the real `ConversationListDependencies`.
    var listDependencies: ConversationListDependencies {
        ConversationListDependencies(
            observeConversations: DecoyConversationsObserver(store: store),
            markRead: DecoyReadMarker(store: store),
            sync: DecoyConversationSyncer(),
            start: DecoyConversationStarter(store: store),
            conversations: store,
            now: now
        )
    }

    /// Drop-in replacement for the real `ChatDependencies`. Sends stay on the device.
    var chatDependencies: ChatDependencies {
        ChatDependencies(
            currentUserId: localUserId,
            observeMessages: DecoyConversationObserver(store: store),
            sender: DecoyMessageSender(store: store, localUserId: localUserId, now: now),
            markRead: DecoyReadMarker(store: store),
            messages: store,
            conversations: store,
            contacts: store,
            typing: DecoyTypingSignaller(),
            envelopes: DecoyEnvelopeProvider(store: store),
            sensitiveDetector: CoreSensitiveContentDetector(),
            attachments: nil,
            now: now
        )
    }

    func conversation(id: ConversationID) async -> Conversation? {
        try? await store.fetch(id: id)
    }
}
