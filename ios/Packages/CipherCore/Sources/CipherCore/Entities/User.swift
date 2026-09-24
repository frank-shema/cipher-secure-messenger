import Foundation

/// A relay account as the directory describes it. Display names are relay-visible metadata, never
/// part of the encrypted payload, so they are safe to show before any key is pinned.
public struct User: Hashable, Codable, Sendable, Identifiable {
    public var id: UserID
    public var username: String
    public var displayName: String

    public init(id: UserID, username: String, displayName: String) {
        self.id = id
        self.username = username
        self.displayName = displayName
    }
}
