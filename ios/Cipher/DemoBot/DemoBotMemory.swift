#if DEBUG
import CipherCore
import Foundation

/// What Echo remembers between launches: which accounts it has already introduced itself to, and the
/// next outgoing counter for each conversation.
///
/// Echo's message store is deliberately in-memory (a fresh client every launch is part of the demo), so
/// without the first note the greeting would replay on every relaunch, and without the second Echo would
/// start counting from 0 again and the person's replay guard would reject its messages as repeats.
/// `UserDefaults` is documented as thread-safe but not marked `Sendable` by the SDK, hence the unchecked
/// conformance; nothing else is stored here.
struct DemoBotMemory: @unchecked Sendable {
    enum Key {
        static let greetedUserIds = "cipher.debug.echo.greetedUserIds"
        static let sendCounters = "cipher.debug.echo.sendCounters"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasGreeted(_ userId: UserID) -> Bool {
        greeted().contains(userId.description)
    }

    func markGreeted(_ userId: UserID) {
        var ids = greeted()
        ids.insert(userId.description)
        defaults.set(Array(ids).sorted(), forKey: Key.greetedUserIds)
    }

    /// Makes Echo introduce itself again to everyone; handy after resetting a relay. Send counters are
    /// kept on purpose: a relay reset does not reset what a peer's device has already seen.
    func forgetEveryone() {
        defaults.removeObject(forKey: Key.greetedUserIds)
    }

    /// Reserves the next outgoing counter for `conversationId`: never below `floor`, never one handed
    /// out before, and records its successor so the next launch continues where this one stopped.
    func reserveSendCounter(conversationId: ConversationID, atLeast floor: UInt64) -> UInt64 {
        var counters = sendCounters()
        let key = conversationId.description
        let stored = counters[key].map { UInt64(clamping: $0) } ?? 0
        let reserved = max(stored, floor)
        counters[key] = Int(clamping: reserved + 1)
        defaults.set(counters, forKey: Key.sendCounters)
        return reserved
    }

    private func greeted() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.greetedUserIds) ?? [])
    }

    private func sendCounters() -> [String: Int] {
        defaults.dictionary(forKey: Key.sendCounters) as? [String: Int] ?? [:]
    }
}
#endif
