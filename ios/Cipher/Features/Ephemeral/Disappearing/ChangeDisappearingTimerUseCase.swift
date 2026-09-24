import CipherCore
import Foundation

/// Changes a conversation's disappearing timer the way the protocol expects: the choice is
/// persisted locally first, then announced with an encrypted `disappearing_changed` system message
/// so both transcripts show the same notice from the same moment.
///
/// The new value travels as the notice's own `flags.disappearAfter`, which is the only place the
/// payload can carry a duration without inventing fields. It doubles as the rule the notice obeys:
/// a notice sent under a timer expires like every other message sent under it, and a notice that
/// turns the timer off has nothing to count down, so it stays.
struct ChangeDisappearingTimerUseCase: Sendable {
    private let store: any DisappearingTimerStoring
    private let sender: any MessageSending
    private let policy: ExpiryPolicyApplier
    private let now: @Sendable () -> Date

    init(
        store: any DisappearingTimerStoring,
        sender: any MessageSending,
        policy: ExpiryPolicyApplier = ExpiryPolicyApplier(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.sender = sender
        self.policy = policy
        self.now = now
    }

    /// Persists `timer` and sends the notice. Returns the notice as persisted so the caller can
    /// show a failure on the row if the relay rejected it; the local setting stays either way,
    /// because a person's own device should honour their choice even while offline.
    @discardableResult
    func execute(conversationId: ConversationID, timer: DisappearingTimer) async throws -> Message {
        try await store.setDisappearingTimer(conversationId: conversationId, timer: timer.seconds)
        EphemeralLog.timer.info(
            "timer set conversation=\(conversationId.description, privacy: .public) seconds=\(timer.rawValue, privacy: .public)"
        )
        let sentAt = now()
        let flags = MessageFlags(disappearAfter: timer.seconds)
        let payload = MessagePayload(type: .system, flags: flags, system: SystemEvent(kind: .disappearingChanged))
        let expiresAt = policy.expiresAt(sentAt: sentAt, flags: flags, conversationTimer: timer.seconds)
        return try await sender.execute(conversationId: conversationId, payload: payload, expiresAt: expiresAt)
    }
}
