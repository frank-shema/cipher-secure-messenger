import Foundation

/// An emoji reaction to another message. `remove` retracts a previous reaction with the same emoji.
public struct Reaction: Hashable, Sendable {
    public var targetId: MessageID
    public var emoji: String
    public var remove: Bool

    public init(targetId: MessageID, emoji: String, remove: Bool = false) {
        self.targetId = targetId
        self.emoji = emoji
        self.remove = remove
    }
}

extension Reaction: Codable {
    private enum CodingKeys: String, CodingKey {
        case targetId
        case emoji
        case remove
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetId = try container.decode(MessageID.self, forKey: .targetId)
        emoji = try container.decode(String.self, forKey: .emoji)
        remove = try container.decodeIfPresent(Bool.self, forKey: .remove) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetId, forKey: .targetId)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(remove, forKey: .remove)
    }
}
