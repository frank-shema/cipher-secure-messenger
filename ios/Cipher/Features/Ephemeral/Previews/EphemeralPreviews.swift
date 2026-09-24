import CipherCore
import Foundation

/// Preview stand-in for `PersistenceStore.deleteExpired(now:)`: hands back a fresh id on every
/// `expiringEvery`-th sweep so a countdown demo has something to report.
actor PreviewExpiredMessageDeleter: ExpiredMessageDeleting {
    private let expiringEvery: Int
    private var sweeps = 0

    init(expiringEvery: Int = 1) {
        self.expiringEvery = max(1, expiringEvery)
    }

    func deleteExpired(now: Date) async throws -> [MessageID] {
        sweeps += 1
        return sweeps.isMultiple(of: expiringEvery) ? [MessageID()] : []
    }
}

/// Preview stand-in for `PersistenceStore.setDisappearingTimer`: records every change.
actor PreviewDisappearingTimerStore: DisappearingTimerStoring {
    private(set) var timers: [ConversationID: TimeInterval?] = [:]

    init() {}

    func setDisappearingTimer(conversationId: ConversationID, timer: TimeInterval?) async throws {
        timers[conversationId] = timer
    }
}
