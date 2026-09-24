import Foundation

/// `/api/v1/keys/*` (PROTOCOL.md §1.2). Public keys only; the relay stores what it is given.
public protocol KeyDirectoryGateway: Sendable {
    /// First upload. The relay refuses to overwrite different keys (409); rotation is explicit.
    func uploadKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle
    /// Replaces the published keys (version + 1) and makes the relay emit `key.changed` to contacts.
    func rotateKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle
    func fetchKeys(userId: UserID) async throws -> RemoteKeyBundle
    func lookup(username: String) async throws -> RemoteKeyBundle
}
