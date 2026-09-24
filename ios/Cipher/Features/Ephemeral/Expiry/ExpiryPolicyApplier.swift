import CipherCore
import Foundation

/// Decides the relay-visible `expiresAt` for a message and the flags that go inside the ciphertext.
///
/// WHY `expiresAt` is visible at all: it is the one content-related field the envelope carries in
/// the clear (PROTOCOL.md §1.3). The relay needs it, and only it, to purge its own opaque copy of
/// a disappearing message; everything else about the timer (that it exists, how long, whether the
/// message was read) stays inside `flags`. Exposing a single instant leaks "this message expires",
/// which is a smaller leak than keeping ciphertext on the relay forever.
///
/// WHY it is anchored to `sentAt` rather than to the read: the sender must fix the instant before
/// the envelope leaves the device, and the recipient receives that same instant in the envelope.
/// Both sides therefore count down to one shared moment and delete together, with no receipt
/// round trip and no clock the relay could tamper with after the fact. On the incoming side there
/// is nothing extra to compute: `Message.expiresAt` already is the envelope's value.
struct ExpiryPolicyApplier: Sendable {
    /// What a send carries: the flags inside the ciphertext and the instant on the envelope.
    struct Outcome: Hashable, Sendable {
        var flags: MessageFlags
        var expiresAt: Date?
    }

    /// The outgoing rule: `sentAt + timer` when a timer applies, otherwise `nil`. The per-message
    /// flag wins over the conversation default because the sender chose it for this message.
    func expiresAt(sentAt: Date, flags: MessageFlags, conversationTimer: TimeInterval?) -> Date? {
        guard let seconds = effectiveTimer(flags: flags, conversationTimer: conversationTimer) else { return nil }
        return sentAt.addingTimeInterval(seconds)
    }

    /// Convenience for a preset timer with no per-message override.
    func expiresAt(sentAt: Date, timer: DisappearingTimer) -> Date? {
        timer.seconds.map { sentAt.addingTimeInterval($0) }
    }

    /// Fills `disappearAfter` from the conversation default when the composer left it unset, so
    /// the recipient's copy of the flags agrees with the envelope's `expiresAt`.
    func flags(_ composed: MessageFlags, conversationTimer: TimeInterval?) -> MessageFlags {
        var flags = composed
        flags.disappearAfter = effectiveTimer(flags: composed, conversationTimer: conversationTimer)
        return flags
    }

    /// Flags and expiry for one send, computed together so they can never disagree.
    func apply(flags composed: MessageFlags, conversationTimer: TimeInterval?, sentAt: Date) -> Outcome {
        let resolved = flags(composed, conversationTimer: conversationTimer)
        return Outcome(flags: resolved, expiresAt: expiresAt(sentAt: sentAt, flags: resolved, conversationTimer: conversationTimer))
    }

    /// The incoming rule: keep what the envelope said. Reading does not move the deadline, because
    /// the sender's device is already counting down to the same instant.
    func expiresAt(forIncoming message: Message) -> Date? {
        message.expiresAt
    }

    /// Whether `message` should be gone by `now`, for renderers that run ahead of the sweep.
    func isExpired(_ message: Message, now: Date) -> Bool {
        guard let expiresAt = message.expiresAt else { return false }
        return now >= expiresAt
    }

    private func effectiveTimer(flags: MessageFlags, conversationTimer: TimeInterval?) -> TimeInterval? {
        let candidate = flags.disappearAfter ?? conversationTimer
        guard let candidate, candidate.isFinite, candidate > 0 else { return nil }
        return candidate
    }
}
