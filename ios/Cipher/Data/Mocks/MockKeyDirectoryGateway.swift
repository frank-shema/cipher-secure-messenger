import CipherCore
import Foundation

/// In-memory `/keys/*`. Pre-seeded with the fixture users so lookups by username succeed in previews;
/// the upload behaviour is configurable to preview the 409 conflict path.
actor MockKeyDirectoryGateway: KeyDirectoryGateway {
    enum UploadBehavior: Sendable {
        case accept
        /// Every `uploadKeys` answers 409 until `rotateKeys` succeeds.
        case conflict
    }

    enum Failure: ProblemPresentable, LocalizedError, Hashable {
        case keysAlreadyRegistered
        case userNotFound
        case keysNotRegistered

        var problemType: String? {
            switch self {
            case .keysAlreadyRegistered: KeyPublishErrorClassifier.conflictProblemType
            case .userNotFound: "urn:cipher:problem:user-not-found"
            case .keysNotRegistered: "urn:cipher:problem:keys-not-registered"
            }
        }

        var problemStatus: Int? {
            switch self {
            case .keysAlreadyRegistered: 409
            case .userNotFound, .keysNotRegistered: 404
            }
        }

        var problemTitle: String? {
            switch self {
            case .keysAlreadyRegistered: String(localized: "mock.keys.conflict.title", defaultValue: "Keys already registered")
            case .userNotFound: String(localized: "mock.keys.userNotFound.title", defaultValue: "User not found")
            case .keysNotRegistered: String(localized: "mock.keys.notRegistered.title", defaultValue: "No keys published")
            }
        }

        var problemDetail: String? {
            switch self {
            case .keysAlreadyRegistered:
                String(localized: "mock.keys.conflict.detail", defaultValue: "Identity keys exist for this user. Rotate explicitly.")
            case .userNotFound:
                String(localized: "mock.keys.userNotFound.detail", defaultValue: "No account has that username.")
            case .keysNotRegistered:
                String(localized: "mock.keys.notRegistered.detail", defaultValue: "This user has not published keys yet.")
            }
        }

        var correlationId: String? { "preview-correlation" }
        var errorDescription: String? { problemDetail }
    }

    private var bundles: [UserID: RemoteKeyBundle]
    private var uploadBehavior: UploadBehavior
    private let currentUser: User
    private let latency: Duration
    private let clock: any Clock

    init(
        currentUser: User = Fixtures.alice,
        seeded: [User] = Fixtures.users,
        uploadBehavior: UploadBehavior = .accept,
        latency: Duration = .milliseconds(500),
        clock: any Clock = SystemClock()
    ) {
        self.currentUser = currentUser
        self.uploadBehavior = uploadBehavior
        self.latency = latency
        self.clock = clock
        self.bundles = Dictionary(uniqueKeysWithValues: seeded.filter { $0.id != currentUser.id }.map {
            ($0.id, RemoteKeyBundle(user: $0, keys: Fixtures.keyBundle(for: $0)))
        })
    }

    func setUploadBehavior(_ behavior: UploadBehavior) {
        uploadBehavior = behavior
    }

    func uploadKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        try await Task.sleep(for: latency)
        if case .conflict = uploadBehavior { throw Failure.keysAlreadyRegistered }
        if let existing = bundles[currentUser.id]?.keys {
            let same = existing.identityKey == upload.identityKey && existing.signingKey == upload.signingKey
            guard same else { throw Failure.keysAlreadyRegistered }
            return existing
        }
        let bundle = PublicKeyBundle(
            userId: currentUser.id,
            identityKey: upload.identityKey,
            signingKey: upload.signingKey,
            version: 1,
            createdAt: clock.now()
        )
        bundles[currentUser.id] = RemoteKeyBundle(user: currentUser, keys: bundle)
        return bundle
    }

    func rotateKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        try await Task.sleep(for: latency)
        let version = (bundles[currentUser.id]?.keys.version ?? 0) + 1
        let bundle = PublicKeyBundle(
            userId: currentUser.id,
            identityKey: upload.identityKey,
            signingKey: upload.signingKey,
            version: version,
            createdAt: clock.now()
        )
        bundles[currentUser.id] = RemoteKeyBundle(user: currentUser, keys: bundle)
        uploadBehavior = .accept
        return bundle
    }

    func fetchKeys(userId: UserID) async throws -> RemoteKeyBundle {
        try await Task.sleep(for: latency)
        guard let bundle = bundles[userId] else { throw Failure.keysNotRegistered }
        return bundle
    }

    func lookup(username: String) async throws -> RemoteKeyBundle {
        try await Task.sleep(for: latency)
        guard let bundle = bundles.values.first(where: { $0.user.username == username }) else { throw Failure.userNotFound }
        return bundle
    }
}
