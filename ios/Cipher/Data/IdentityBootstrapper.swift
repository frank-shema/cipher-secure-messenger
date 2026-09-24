import CipherCore
import Foundation

/// The three visible phases of identity bootstrap, in order. The UI animates one row per step while
/// the real work runs, so the enum doubles as the step list.
enum KeyBootstrapStep: Int, CaseIterable, Hashable, Sendable {
    case generating
    case sealing
    case publishing
}

/// How a bootstrap ended when it did not throw.
enum KeyBootstrapOutcome: Hashable, Sendable {
    /// `PUT /keys/me` answered 200 or 201: the relay holds exactly this device's public keys.
    case published(PublicKeyBundle)
    /// `PUT /keys/me` answered 409: different keys exist for this account (another device, or a
    /// reinstall). Nothing was overwritten; the person must choose to rotate explicitly.
    case conflict
}

/// Decides whether a `KeyDirectoryGateway.uploadKeys` failure is the 409 "keys already registered"
/// answer. Injected because the transport error type belongs to the networking module.
struct KeyPublishErrorClassifier: Sendable {
    static let conflictProblemType = "urn:cipher:problem:keys-already-registered"

    let isConflict: @Sendable (any Error) -> Bool

    /// Recognises any `ProblemPresentable` carrying the protocol's conflict type or a 409 status.
    static let problemBased = KeyPublishErrorClassifier { error in
        guard let problem = error as? any ProblemPresentable else { return false }
        return problem.problemType == conflictProblemType || problem.problemStatus == 409
    }
}

/// Runs identity bootstrap after sign-in: make sure this device has Curve25519 keys, then publish the
/// public halves. Private material never leaves the `IdentityKeyStore`; this type only ever sees the
/// `PublicKeyBundleUpload` it hands to the directory.
struct IdentityBootstrapper: Sendable {
    private let keyStore: any IdentityKeyStore
    private let directory: any KeyDirectoryGateway
    private let classifier: KeyPublishErrorClassifier

    init(keyStore: any IdentityKeyStore, directory: any KeyDirectoryGateway, classifier: KeyPublishErrorClassifier) {
        self.keyStore = keyStore
        self.directory = directory
        self.classifier = classifier
    }

    /// Idempotent: existing keys are reused, and re-uploading identical keys is a 200 on the relay.
    func run(progress: @Sendable (KeyBootstrapStep) async -> Void) async throws -> KeyBootstrapOutcome {
        await progress(.generating)
        let upload: PublicKeyBundleUpload
        if try await keyStore.hasIdentity() {
            upload = try await keyStore.publicKeys()
            AppLog.identity.info("reusing existing identity")
        } else {
            upload = try await keyStore.createIdentity()
            AppLog.identity.info("created identity")
        }
        // `createIdentity` persists before returning, so by here the keys are sealed at rest.
        await progress(.sealing)
        await progress(.publishing)
        do {
            let bundle = try await directory.uploadKeys(upload)
            AppLog.identity.info("published keys v\(bundle.version, privacy: .public)")
            return .published(bundle)
        } catch where classifier.isConflict(error) {
            AppLog.identity.notice("relay holds different keys; awaiting explicit rotation")
            return .conflict
        }
    }

    /// Explicit rotation after a conflict: discards the local keys, generates fresh ones and replaces the
    /// published bundle (version + 1). Contacts receive `key.changed`, which is the point: rotation must
    /// be visible to them, never silent.
    func rotate() async throws -> PublicKeyBundle {
        try await keyStore.deleteIdentity()
        let upload = try await keyStore.createIdentity()
        let bundle = try await directory.rotateKeys(upload)
        AppLog.identity.notice("rotated keys to v\(bundle.version, privacy: .public)")
        return bundle
    }
}
