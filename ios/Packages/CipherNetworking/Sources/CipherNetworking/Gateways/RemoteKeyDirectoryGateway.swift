import CipherCore
import Foundation

/// `KeyDirectoryGateway` over `/keys/*`. Returns whatever the relay stores; validating key lengths and
/// deciding whether to trust a changed key is Core's job (`ContactPinning`), not the transport's.
public struct RemoteKeyDirectoryGateway: KeyDirectoryGateway {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func uploadKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        let bundle = try await client.send(UploadKeysEndpoint(upload))
        NetLog.api.info("uploaded keys v\(bundle.version, privacy: .public) for \(bundle.userId.description, privacy: .public)")
        return bundle.keys
    }

    public func rotateKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        let bundle = try await client.send(RotateKeysEndpoint(upload))
        NetLog.api.notice("rotated keys to v\(bundle.version, privacy: .public) for \(bundle.userId.description, privacy: .public)")
        return bundle.keys
    }

    /// The caller's own published bundle, for the Settings screen and for detecting a stale upload
    /// after a reinstall.
    public func fetchMyKeys() async throws -> RemoteKeyBundle {
        try await client.send(FetchMyKeysEndpoint()).toDomain()
    }

    public func fetchKeys(userId: UserID) async throws -> RemoteKeyBundle {
        try await client.send(FetchKeysEndpoint(userId: userId)).toDomain()
    }

    public func lookup(username: String) async throws -> RemoteKeyBundle {
        try await client.send(LookupKeysEndpoint(username: username)).toDomain()
    }
}
