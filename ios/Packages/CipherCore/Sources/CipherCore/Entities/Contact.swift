import Foundation

/// A peer the local user has exchanged (or is about to exchange) messages with, together with the
/// keys pinned for them. `id` is always `user.id`; it is derived rather than stored so the two can
/// never drift apart.
public struct Contact: Hashable, Codable, Sendable, Identifiable {
    public var user: User
    public var keys: PublicKeyBundle?
    public var trust: TrustState
    public var presence: Presence

    public init(user: User, keys: PublicKeyBundle?, trust: TrustState, presence: Presence) {
        self.user = user
        self.keys = keys
        self.trust = trust
        self.presence = presence
    }

    public var id: UserID {
        user.id
    }
}
