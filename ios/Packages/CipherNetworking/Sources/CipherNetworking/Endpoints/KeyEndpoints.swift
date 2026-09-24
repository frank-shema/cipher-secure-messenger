import CipherCore
import Foundation

// `/api/v1/keys/*` (PROTOCOL.md §1.2).

/// `PUT /keys/me`. First upload: the relay answers 409 `keys-already-registered` when different keys
/// exist, so a reinstalled app can never silently replace the identity contacts have pinned.
public struct UploadKeysEndpoint: Endpoint {
    public typealias Response = KeyBundleDTO

    public var request: KeyUploadRequest

    public init(_ upload: PublicKeyBundleUpload) {
        self.request = KeyUploadRequest(upload)
    }

    public var path: String { "keys/me" }
    public var method: HTTPMethod { .put }
    public var body: RequestBody { .json(request) }
}

/// `POST /keys/me/rotate`. Explicit rotation: bumps `version` and makes the relay push `key.changed`
/// to every contact.
public struct RotateKeysEndpoint: Endpoint {
    public typealias Response = KeyBundleDTO

    public var request: KeyUploadRequest

    public init(_ upload: PublicKeyBundleUpload) {
        self.request = KeyUploadRequest(upload)
    }

    public var path: String { "keys/me/rotate" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
}

/// `GET /keys/me`.
public struct FetchMyKeysEndpoint: Endpoint {
    public typealias Response = KeyBundleDTO

    public init() {}

    public var path: String { "keys/me" }
    public var method: HTTPMethod { .get }
}

/// `GET /keys/{userId}`.
public struct FetchKeysEndpoint: Endpoint {
    public typealias Response = KeyBundleDTO

    public var userId: UserID

    public init(userId: UserID) {
        self.userId = userId
    }

    public var path: String { "keys/\(userId.description)" }
    public var method: HTTPMethod { .get }
}

/// `GET /keys/lookup?username=`.
public struct LookupKeysEndpoint: Endpoint {
    public typealias Response = KeyBundleDTO

    public var username: String

    public init(username: String) {
        self.username = username
    }

    public var path: String { "keys/lookup" }
    public var method: HTTPMethod { .get }
    public var query: [URLQueryItem] { [URLQueryItem(name: "username", value: username)] }
}
