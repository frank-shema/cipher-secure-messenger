import Foundation

/// A type-safe UUID. The phantom `Tag` makes `UserID`, `ConversationID`, `MessageID` and `BlobID`
/// distinct types, so passing a message id where a user id is expected is a compile error rather
/// than a routing bug that only shows up against a live relay.
public struct Identifier<Tag>: Hashable, Sendable, CustomStringConvertible {
    public let uuid: UUID

    public init() {
        self.uuid = UUID()
    }

    public init(_ uuid: UUID) {
        self.uuid = uuid
    }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    /// Lowercase hyphenated form, the canonical spelling PROTOCOL.md mandates. Both the JSON encoding
    /// and the AEAD associated data use this, so the two can never disagree by letter case.
    public var description: String {
        uuid.uuidString.lowercased()
    }
}

extension Identifier: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let uuid = UUID(uuidString: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a UUID string")
        }
        self.uuid = uuid
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public enum UserTag {}
public enum ConversationTag {}
public enum MessageTag {}
public enum BlobTag {}

public typealias UserID = Identifier<UserTag>
public typealias ConversationID = Identifier<ConversationTag>
public typealias MessageID = Identifier<MessageTag>
public typealias BlobID = Identifier<BlobTag>
