import Foundation
import SwiftData

/// A `(senderId, conversationId, counter)` triple that was successfully opened once. The composite
/// `key` column carries the uniqueness because compound `#Unique` constraints need iOS 18, and the
/// deployment target is iOS 17; the three source columns remain for diagnostics and pruning.
@Model
final class StoredSeenCounter {
    @Attribute(.unique) var key: String
    var senderId: UUID
    var conversationId: UUID
    var counter: Int64
    var seenAt: Date

    init(key: String, senderId: UUID, conversationId: UUID, counter: Int64, seenAt: Date) {
        self.key = key
        self.senderId = senderId
        self.conversationId = conversationId
        self.counter = counter
        self.seenAt = seenAt
    }

    static func makeKey(senderId: UUID, conversationId: UUID, counter: Int64) -> String {
        "\(senderId.uuidString.lowercased())|\(conversationId.uuidString.lowercased())|\(counter)"
    }
}
