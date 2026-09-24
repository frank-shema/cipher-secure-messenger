import Foundation

/// In-memory record of attachment sends whose blob has not reached the relay yet, keyed by the
/// message id that was chosen up front. Retrying re-uses the same key and id so the bubble the person
/// is looking at is the one that eventually turns green, rather than a duplicate appearing below it.
///
/// Deliberately not persisted: plaintext bytes must never be written to disk before sealing, and a
/// relaunch mid-upload is handled by asking the person to pick the file again.
public actor PendingAttachmentSends {
    struct Entry: Sendable {
        var request: SendAttachmentUseCase.Request
        var key: Data
        var attempts: Int
    }

    private var entries: [MessageID: Entry] = [:]

    public init() {}

    func store(_ entry: Entry, for messageId: MessageID) {
        entries[messageId] = entry
    }

    func entry(for messageId: MessageID) -> Entry? {
        entries[messageId]
    }

    func markAttempt(for messageId: MessageID) {
        entries[messageId]?.attempts += 1
    }

    func remove(_ messageId: MessageID) {
        entries.removeValue(forKey: messageId)
    }

    /// Whether a retry can re-upload from memory; false means the outbox path (or nothing) applies.
    public func isPending(_ messageId: MessageID) -> Bool {
        entries[messageId] != nil
    }

    public var count: Int {
        entries.count
    }
}

/// Hands `SendMessageUseCase` a message id chosen before the upload started, so the placeholder
/// bubble that showed the upload ring and the final sent message are the same row.
struct PresetUUIDGenerator: UUIDGenerator {
    let uuid: UUID

    func next() -> UUID {
        uuid
    }
}
