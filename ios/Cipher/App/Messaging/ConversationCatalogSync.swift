import CipherCore
import Foundation

/// What happens every time the socket comes up: queued sends leave first (their counters must reach
/// the relay in order), then conversations this device has never seen are pulled from the relay,
/// then every conversation's history is synced so receipts and messages missed offline land.
///
/// Each step is independent and logs its own failure; a relay that answers half the calls still
/// leaves the inbox as complete as it can be.
struct ConversationCatalogSync: Sendable {
    private let stack: MessagingStack
    private let timerSync: DisappearingTimerSync

    init(stack: MessagingStack, timerSync: DisappearingTimerSync) {
        self.stack = stack
        self.timerSync = timerSync
    }

    func run() async {
        await flushOutbox()
        guard !Task.isCancelled else { return }
        await discoverConversations()
        guard !Task.isCancelled else { return }
        await syncAllConversations()
    }

    private func flushOutbox() async {
        do {
            let report = try await stack.flushOutbox.execute()
            let sent = report.sent.count
            let deferred = report.deferred.count
            AppLog.realtime.info("outbox flushed sent=\(sent, privacy: .public) deferred=\(deferred, privacy: .public)")
        } catch {
            AppLog.realtime.error("outbox flush failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Conversations that exist on the relay but not on this device (a reinstall, or a chat started
    /// by the other side whose messages were already acknowledged elsewhere).
    private func discoverConversations() async {
        do {
            let remote = try await stack.conversationGateway.list()
            var added = 0
            for conversation in remote where try await stack.conversations.fetch(id: conversation.id) == nil {
                guard let peer = conversation.counterpart(of: stack.account.id) else { continue }
                let contact = try await pinContact(for: peer)
                let local = Conversation(
                    id: conversation.id,
                    contact: contact,
                    lastMessage: nil,
                    unreadCount: 0,
                    updatedAt: conversation.lastMessageAt ?? conversation.createdAt,
                    disappearingTimer: nil
                )
                try await stack.conversations.upsert(local)
                added += 1
            }
            if added > 0 {
                AppLog.realtime.info("discovered \(added, privacy: .public) conversations")
            }
        } catch {
            AppLog.realtime.error("conversation discovery failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Reuses a pinned contact; otherwise pins the directory's keys as `unverified`. A later key
    /// change is still detected by `ReceiveEnvelopeUseCase`, which re-pins on every unknown sender.
    private func pinContact(for peer: User) async throws -> Contact {
        if let existing = try await stack.contacts.fetch(userId: peer.id) {
            return existing
        }
        let remote = try await stack.keyDirectory.fetchKeys(userId: peer.id)
        let contact = Contact(user: remote.user, keys: remote.keys, trust: .unverified, presence: .unknown)
        try await stack.contacts.upsert(contact)
        return contact
    }

    private func syncAllConversations() async {
        let conversations: [Conversation]
        do {
            conversations = try await stack.conversations.fetchAll()
        } catch {
            AppLog.realtime.error("conversation list unavailable: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        for conversation in conversations {
            guard !Task.isCancelled else { return }
            do {
                let received = try await stack.syncConversation.execute(conversationId: conversation.id)
                try await timerSync.apply(received)
            } catch {
                let failure = String(describing: type(of: error))
                AppLog.realtime.error("sync failed for \(conversation.id.description, privacy: .public): \(failure, privacy: .public)")
            }
        }
    }
}
