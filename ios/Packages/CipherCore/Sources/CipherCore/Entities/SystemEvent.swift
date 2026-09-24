import Foundation

/// An end-to-end encrypted notice about something that happened on the other device. Sent as a real
/// message so the relay cannot tell a screenshot notice from a text.
public struct SystemEvent: Hashable, Sendable {
    public enum Kind: String, Hashable, Codable, Sendable, CaseIterable {
        case screenshotTaken = "screenshot_taken"
        case viewOnceOpened = "view_once_opened"
        case disappearingChanged = "disappearing_changed"
        case keyVerified = "key_verified"
    }

    public var kind: Kind
    /// The message the event refers to, when there is one.
    public var refId: MessageID?

    public init(kind: Kind, refId: MessageID? = nil) {
        self.kind = kind
        self.refId = refId
    }
}

extension SystemEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case refId
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        refId = try container.decodeIfPresent(MessageID.self, forKey: .refId)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(refId, forKey: .refId)
    }
}
