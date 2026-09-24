import CipherCore
import CipherDesign
import Foundation
import Observation

/// Opens Time Capsules at the right moment. Rows register the capsules they show; the coordinator
/// keeps one timer armed for the earliest `unlockAt` instead of one per bubble, marks each capsule
/// unlocked when its instant passes, plays the `capsuleUnlock` haptic once per batch and hands the
/// ids to the ViewModel so the bubble can start its decrypt reveal.
///
/// The seal is a promise this client keeps, not one the relay can enforce: `unlockAt` lives inside
/// the ciphertext. Re-evaluating on foreground covers the common case where the moment passed
/// while the app was suspended and no timer could fire.
@MainActor
@Observable
final class TimeCapsuleUnlockCoordinator {
    /// Capsules whose instant passed while tracked; rows render these as plain bubbles.
    private(set) var unlockedIds: Set<MessageID> = []
    /// Called once per unlocked capsule, after the haptic, for the ViewModel's bookkeeping.
    @ObservationIgnored var onUnlock: @MainActor (MessageID) -> Void = { _ in }

    @ObservationIgnored private let haptics: any HapticEngine
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var tracked: [MessageID: Date] = [:]
    @ObservationIgnored private var timer: Task<Void, Never>?

    init(haptics: any HapticEngine, now: @escaping @Sendable () -> Date = { Date() }) {
        self.haptics = haptics
        self.now = now
    }

    /// Registers a capsule that is on screen. Messages without `unlockAt`, outgoing messages (the
    /// sender always sees their own text) and already-open capsules are ignored.
    func track(_ message: Message) {
        guard message.direction == .incoming, let unlockAt = message.flags.unlockAt else { return }
        track(messageId: message.id, unlockAt: unlockAt)
    }

    func track(messageId: MessageID, unlockAt: Date) {
        guard !unlockedIds.contains(messageId) else { return }
        if unlockAt <= now() {
            unlock([messageId])
            return
        }
        tracked[messageId] = unlockAt
        rearm()
    }

    /// Stops watching a capsule that scrolled away; its state is kept so scrolling back is free.
    func untrack(_ messageId: MessageID) {
        guard tracked.removeValue(forKey: messageId) != nil else { return }
        rearm()
    }

    /// Whether the row should still draw the seal.
    func isSealed(_ message: Message) -> Bool {
        guard message.direction == .incoming, let unlockAt = message.flags.unlockAt else { return false }
        return unlockAt > now() && !unlockedIds.contains(message.id)
    }

    func isUnlocked(_ messageId: MessageID) -> Bool {
        unlockedIds.contains(messageId)
    }

    /// Opens everything whose moment passed while the process was suspended.
    func applicationDidBecomeActive() {
        fireDue()
    }

    /// Forgets everything; for sign-out and for leaving the chat for good.
    func reset() {
        timer?.cancel()
        timer = nil
        tracked.removeAll()
        unlockedIds.removeAll()
    }

    private func rearm() {
        timer?.cancel()
        timer = nil
        guard let next = tracked.values.min() else { return }
        let delay = max(0, next.timeIntervalSince(now()))
        let count = tracked.count
        let seconds = Int(delay.rounded())
        EphemeralLog.capsule.debug("next unlock in \(seconds, privacy: .public)s for \(count, privacy: .public) capsules")
        timer = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay), clock: .continuous)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.fireDue()
        }
    }

    private func fireDue() {
        let instant = now()
        let due = tracked.filter { $0.value <= instant }.map(\.key)
        for id in due { tracked.removeValue(forKey: id) }
        if !due.isEmpty { unlock(due) }
        rearm()
    }

    private func unlock(_ ids: [MessageID]) {
        let fresh = ids.filter { !unlockedIds.contains($0) }
        guard !fresh.isEmpty else { return }
        unlockedIds.formUnion(fresh)
        haptics.play(.capsuleUnlock)
        EphemeralLog.capsule.info("unlocked \(fresh.count, privacy: .public) capsules")
        for id in fresh { onUnlock(id) }
    }
}
