import Foundation

/// Relay-observed online state. Purely informational and never authenticated.
public struct Presence: Hashable, Codable, Sendable {
    public var online: Bool
    public var lastSeenAt: Date?

    public init(online: Bool, lastSeenAt: Date?) {
        self.online = online
        self.lastSeenAt = lastSeenAt
    }

    public static let unknown = Presence(online: false, lastSeenAt: nil)
}
