#if DEBUG
import CipherCore
import CipherNetworking
import Foundation

/// Makes sure the relay holds the companion's current public keys.
///
/// The keys live in their own Keychain service and survive relaunches, so the relay normally already
/// has them (`GET /keys/me` answers with identical material). A 404 means a relay that has never seen
/// them: upload. Different material means the relay and this simulator's Keychain have drifted apart
/// (one of them was reset); the demo account rotates rather than stalls, and contacts get the honest
/// `key.changed` warning, which is itself worth demonstrating.
struct DemoBotIdentity: Sendable {
    private let keyStore: any IdentityKeyStore
    private let directory: RemoteKeyDirectoryGateway

    init(keyStore: any IdentityKeyStore, directory: RemoteKeyDirectoryGateway) {
        self.keyStore = keyStore
        self.directory = directory
    }

    @discardableResult
    func publish() async throws -> PublicKeyBundle {
        let upload = try await localKeys()
        let remote: RemoteKeyBundle
        do {
            remote = try await directory.fetchMyKeys()
        } catch let error as APIError where error.statusCode == 404 {
            DemoBotLog.account.info("relay has no companion keys; uploading")
            return try await directory.uploadKeys(upload)
        }
        if remote.keys.identityKey == upload.identityKey, remote.keys.signingKey == upload.signingKey {
            DemoBotLog.account.info("relay already holds companion keys v\(remote.keys.version, privacy: .public)")
            return remote.keys
        }
        DemoBotLog.account.notice("relay keys differ from local keys; rotating past v\(remote.keys.version, privacy: .public)")
        return try await directory.rotateKeys(upload)
    }

    private func localKeys() async throws -> PublicKeyBundleUpload {
        if try await keyStore.hasIdentity() {
            return try await keyStore.publicKeys()
        }
        DemoBotLog.account.info("creating companion identity")
        return try await keyStore.createIdentity()
    }
}
#endif
