import CipherCore
import CipherPersistence
import Foundation

/// Persists the per-conversation disappearing timer. Core's `ConversationRepository` has no
/// dedicated setter (the timer rides along on `upsert`), while `PersistenceStore` keeps it in its
/// own settings row so a history sync can never overwrite a person's choice; this port lets the
/// feature target whichever is available without knowing the store.
protocol DisappearingTimerStoring: Sendable {
    /// Sets the default timer for new outgoing messages; `nil` turns disappearing messages off.
    func setDisappearingTimer(conversationId: ConversationID, timer: TimeInterval?) async throws
}

/// Deletes every message whose `expiresAt` has passed. Deleting is the only enforcement a
/// disappearing message has on this device, because the relay cannot read the flag inside the
/// ciphertext and only purges its own opaque copy.
protocol ExpiredMessageDeleting: Sendable {
    /// Removes expired messages and returns their ids so open screens can drop cached rows.
    func deleteExpired(now: Date) async throws -> [MessageID]
}

extension PersistenceStore: DisappearingTimerStoring {}

extension PersistenceStore: ExpiredMessageDeleting {}

/// Timer storage over a plain `ConversationRepository`, for previews and any store that has no
/// dedicated settings table: reads the conversation, changes the timer, writes it back.
struct ConversationRepositoryTimerStore: DisappearingTimerStoring {
    private let conversations: any ConversationRepository

    init(conversations: any ConversationRepository) {
        self.conversations = conversations
    }

    func setDisappearingTimer(conversationId: ConversationID, timer: TimeInterval?) async throws {
        guard var conversation = try await conversations.fetch(id: conversationId) else {
            throw EphemeralError.conversationNotFound(conversationId)
        }
        conversation.disappearingTimer = timer.flatMap { $0 > 0 ? $0 : nil }
        try await conversations.upsert(conversation)
    }
}

/// Failures the ephemeral feature raises itself; store and transport errors pass through typed
/// from their own modules.
enum EphemeralError: Error, LocalizedError, Hashable, Sendable {
    case conversationNotFound(ConversationID)
    case unlockTooSoon(minimum: Date)

    var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return String(localized: "ephemeral.error.conversationNotFound", defaultValue: "This conversation is no longer available.")
        case .unlockTooSoon(let minimum):
            let time = minimum.formatted(date: .omitted, time: .shortened)
            return String(
                localized: "ephemeral.error.unlockTooSoon",
                defaultValue: "A Time Capsule must open at least a minute from now (\(time))."
            )
        }
    }
}
