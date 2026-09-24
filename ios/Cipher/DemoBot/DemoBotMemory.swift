#if DEBUG
import CipherCore
import Foundation

/// What Echo remembers between launches: only which accounts it has already introduced itself to.
///
/// Echo's message store is deliberately in-memory (a fresh client every launch is part of the demo), so
/// without this note the first-contact greeting would replay on every relaunch. `UserDefaults` is
/// documented as thread-safe but not marked `Sendable` by the SDK, hence the unchecked conformance;
/// nothing else is stored here.
struct DemoBotMemory: @unchecked Sendable {
    enum Key {
        static let greetedUserIds = "cipher.debug.echo.greetedUserIds"
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

    /// Makes Echo introduce itself again to everyone; handy after resetting a relay.
    func forgetEveryone() {
        defaults.removeObject(forKey: Key.greetedUserIds)
    }

    private func greeted() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.greetedUserIds) ?? [])
    }
}
#endif
