import CipherCore
import Foundation

/// Records that a view-once message was opened. Persistence implements it; the record must survive a
/// crash mid-view so the photo can never be opened a second time on relaunch.
protocol ViewOnceMarking: Sendable {
    /// Returns `true` only on the first call for a message.
    func markViewed(messageId: MessageID) async throws -> Bool
    func viewedAt(messageId: MessageID) async throws -> Date?
}
