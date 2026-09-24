import Foundation

/// Per-message behaviour switches. They travel inside the ciphertext (PROTOCOL.md §3), so the relay
/// cannot see or enforce any of them; every rule here is applied client-side.
public struct MessageFlags: Hashable, Sendable {
    public var viewOnce: Bool
    public var whisper: Bool
    /// Seconds after the recipient reads the message until both clients delete it.
    public var disappearAfter: TimeInterval?
    /// Time Capsule: the recipient keeps the message sealed until this instant.
    public var unlockAt: Date?

    public init(viewOnce: Bool = false, whisper: Bool = false, disappearAfter: TimeInterval? = nil, unlockAt: Date? = nil) {
        self.viewOnce = viewOnce
        self.whisper = whisper
        self.disappearAfter = disappearAfter
        self.unlockAt = unlockAt
    }

    public static let none = MessageFlags()
}

extension MessageFlags: Codable {
    private enum CodingKeys: String, CodingKey {
        case viewOnce
        case whisper
        case disappearAfter
        case unlockAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewOnce = try container.decodeIfPresent(Bool.self, forKey: .viewOnce) ?? false
        whisper = try container.decodeIfPresent(Bool.self, forKey: .whisper) ?? false
        disappearAfter = try container.decodeIfPresent(Double.self, forKey: .disappearAfter)
        unlockAt = try container.decodeIfPresent(Int64.self, forKey: .unlockAt).map { Date(epochMillis: $0) }
    }

    /// Explicit `null`s mirror the protocol example so encoded payloads have a fixed key set.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(viewOnce, forKey: .viewOnce)
        try container.encode(whisper, forKey: .whisper)
        try container.encode(disappearAfter.map { Int64($0.rounded()) }, forKey: .disappearAfter)
        try container.encode(unlockAt?.epochMillis, forKey: .unlockAt)
    }
}
