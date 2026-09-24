import Foundation

/// The fictional inbox shown in `AppLockMode.decoy`. Held in memory only and never persisted, so a
/// forensic dump of the store finds no trace of it.
public struct DecoyInbox: Hashable, Sendable {
    /// Most recently updated first, as the real list is sorted.
    public var conversations: [Conversation]
    public var messages: [ConversationID: [Message]]

    public init(conversations: [Conversation], messages: [ConversationID: [Message]]) {
        self.conversations = conversations
        self.messages = messages
    }

    /// Oldest first, the order the chat view renders.
    public func messages(in conversationId: ConversationID) -> [Message] {
        messages[conversationId] ?? []
    }
}

/// Produces the same believable-but-fictional inbox for the same seed every time. Determinism matters
/// twice: the decoy must not visibly reshuffle between unlocks, and the same seed must yield the same
/// ids so a chat opened from the list resolves to the same messages after the app restarts.
public struct DecoyInboxGenerator: Sendable {
    public static let defaultConversationCount = 6

    public var seed: UInt64
    /// The local account, used as sender of outgoing lines and recipient of incoming ones.
    public var localUserId: UserID

    public init(seed: UInt64, localUserId: UserID) {
        self.seed = seed
        self.localUserId = localUserId
    }

    /// Builds the inbox relative to `now` so timestamps always read as "yesterday" or "2 h ago"
    /// rather than drifting into the past across launches. Cheap, but callers may still run it
    /// off the main actor alongside the real unlock work.
    public func generate(now: Date, conversationCount: Int = DecoyInboxGenerator.defaultConversationCount) -> DecoyInbox {
        var rng = SplitMix64(seed: seed)
        let count = min(max(conversationCount, 0), min(DecoyScripts.personas.count, DecoyScripts.scripts.count))
        let personas = DecoyScripts.personas.shuffled(using: &rng).prefix(count)
        let scripts = DecoyScripts.scripts.shuffled(using: &rng).prefix(count)

        var conversations: [Conversation] = []
        var messages: [ConversationID: [Message]] = [:]
        var lastActivity = now.addingTimeInterval(-rng.seconds(between: 5 * 60, and: 3 * 60 * 60))
        for (persona, script) in zip(personas, scripts) {
            let contact = makeContact(persona, now: now, rng: &rng)
            let conversationId = ConversationID(rng.uuid())
            let thread = makeThread(script, conversationId: conversationId, contactId: contact.id, endingAt: lastActivity, rng: &rng)
            let unread = Self.unreadCount(for: thread, rng: &rng)
            conversations.append(Conversation(
                id: conversationId,
                contact: contact,
                lastMessage: thread.last,
                unreadCount: unread,
                updatedAt: thread.last?.effectiveTimestamp ?? lastActivity,
                disappearingTimer: nil
            ))
            messages[conversationId] = thread
            lastActivity = lastActivity.addingTimeInterval(-rng.seconds(between: 2 * 60 * 60, and: 20 * 60 * 60))
        }
        CoreLog.security.info("decoy inbox generated conversations=\(conversations.count, privacy: .public)")
        return DecoyInbox(conversations: conversations, messages: messages)
    }

    private func makeContact(_ persona: DecoyScripts.Persona, now: Date, rng: inout SplitMix64) -> Contact {
        let userId = UserID(rng.uuid())
        let keyAge = rng.seconds(between: 20 * 86_400, and: 400 * 86_400)
        let keys = PublicKeyBundle(
            userId: userId,
            identityKey: rng.data(count: PublicKeyBundle.keyLength),
            signingKey: rng.data(count: PublicKeyBundle.keyLength),
            version: 1,
            createdAt: now.addingTimeInterval(-keyAge)
        )
        let trust: TrustState = rng.chance(0.5)
            ? .verified(at: now.addingTimeInterval(-rng.seconds(between: 86_400, and: keyAge)))
            : .unverified
        let online = rng.chance(0.3)
        let presence = Presence(
            online: online,
            lastSeenAt: online ? now : now.addingTimeInterval(-rng.seconds(between: 10 * 60, and: 2 * 86_400))
        )
        return Contact(
            user: User(id: userId, username: persona.username, displayName: persona.displayName),
            keys: keys,
            trust: trust,
            presence: presence
        )
    }

    /// Lays the script out backwards from `endingAt` with human-sized gaps: replies within minutes,
    /// an occasional hours-long pause. Counters run per sender as the protocol requires.
    private func makeThread(
        _ script: [DecoyScripts.Line],
        conversationId: ConversationID,
        contactId: UserID,
        endingAt: Date,
        rng: inout SplitMix64
    ) -> [Message] {
        var timestamps: [Date] = []
        var cursor = endingAt
        for index in script.indices.reversed() {
            timestamps.append(cursor)
            let longPause = index > 0 && rng.chance(0.15)
            let gap = longPause ? rng.seconds(between: 60 * 60, and: 4 * 60 * 60) : rng.seconds(between: 20, and: 8 * 60)
            cursor = cursor.addingTimeInterval(-gap)
        }
        timestamps.reverse()

        var outgoingCounter: UInt64 = UInt64.random(in: 12...90, using: &rng)
        var incomingCounter: UInt64 = UInt64.random(in: 12...90, using: &rng)
        var messages: [Message] = []
        for (line, sentAt) in zip(script, timestamps) {
            let isOutgoing = line.direction == .outgoing
            let counter: UInt64
            if isOutgoing {
                outgoingCounter += 1
                counter = outgoingCounter
            } else {
                incomingCounter += 1
                counter = incomingCounter
            }
            let messageId = MessageID(rng.uuid())
            messages.append(Message(
                id: messageId,
                conversationId: conversationId,
                senderId: isOutgoing ? localUserId : contactId,
                recipientId: isOutgoing ? contactId : localUserId,
                direction: line.direction,
                content: .text(line.text),
                flags: .none,
                replyToId: nil,
                counter: counter,
                sentAt: sentAt,
                serverCreatedAt: sentAt.addingTimeInterval(rng.seconds(between: 0.2, and: 1.5)),
                status: .read,
                expiresAt: nil,
                reactions: Self.reactions(for: line, targetId: messageId, rng: &rng)
            ))
        }
        return messages
    }

    private static func reactions(for line: DecoyScripts.Line, targetId: MessageID, rng: inout SplitMix64) -> [Reaction] {
        guard line.text.contains("!"), rng.chance(0.6) else { return [] }
        let emoji = DecoyScripts.reactions[Int(rng.next() % UInt64(DecoyScripts.reactions.count))]
        return [Reaction(targetId: targetId, emoji: emoji)]
    }

    /// Only a thread whose last line is incoming can be unread, and most are not: an inbox full of
    /// badges looks neglected, which is its own kind of suspicious.
    private static func unreadCount(for thread: [Message], rng: inout SplitMix64) -> Int {
        guard thread.last?.direction == .incoming, rng.chance(0.35) else { return 0 }
        let trailingIncoming = thread.reversed().prefix { $0.direction == .incoming }.count
        return min(trailingIncoming, Int.random(in: 1...2, using: &rng))
    }
}
