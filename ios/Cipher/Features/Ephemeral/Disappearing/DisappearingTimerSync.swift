import CipherCore
import Foundation

/// Applies the other side's timer changes. A `disappearing_changed` notice carries the new value in
/// its `flags.disappearAfter`, so the recipient's conversation adopts it and every message either
/// side sends from then on carries the same `expiresAt`. Without this, the two devices would count
/// down different timers for the same conversation.
///
/// History sync delivers pages newest-first, so an older notice may arrive after a newer one; the
/// actor remembers the newest notice it applied per conversation and ignores anything older.
actor DisappearingTimerSync {
    private let store: any DisappearingTimerStoring
    private var lastApplied: [ConversationID: Date] = [:]

    init(store: any DisappearingTimerStoring) {
        self.store = store
    }

    /// Returns `true` when the message was a timer notice that changed the stored timer.
    @discardableResult
    func apply(_ message: Message) async throws -> Bool {
        guard case .system(let event) = message.content, event.kind == .disappearingChanged else {
            return false
        }
        let at = message.effectiveTimestamp
        if let previous = lastApplied[message.conversationId], previous > at {
            return false
        }
        lastApplied[message.conversationId] = at
        let timer = DisappearingTimer(seconds: message.flags.disappearAfter)
        try await store.setDisappearingTimer(conversationId: message.conversationId, timer: timer.seconds)
        EphemeralLog.timer.info(
            "timer synced conversation=\(message.conversationId.description, privacy: .public) seconds=\(timer.rawValue, privacy: .public)"
        )
        return true
    }

    /// Applies a batch in chronological order, for history sync results.
    func apply(_ messages: [Message]) async throws {
        for message in messages.sorted(by: { $0.effectiveTimestamp < $1.effectiveTimestamp }) {
            try await apply(message)
        }
    }
}
