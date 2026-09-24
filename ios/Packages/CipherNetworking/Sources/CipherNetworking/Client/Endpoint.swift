import Foundation

public enum HTTPMethod: String, Hashable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// What goes on the wire. Multipart is a separate case rather than pre-encoded bytes so the client can
/// stream it through an upload task and report progress.
public enum RequestBody: Sendable {
    case none
    case json(any Encodable & Sendable)
    case multipart(MultipartFormData)
}

/// How the client moves bytes. `buffered` is the normal JSON round trip; the other two route through
/// URLSession upload / byte-stream APIs so `TransferProgress` gets real numbers instead of 0 then 1.
public enum TransferMode: Hashable, Sendable {
    case buffered
    case upload
    case download
}

/// A response body the client knows how to turn into a value. JSON `Decodable` types get this for free;
/// `Empty` and `RawResponse` exist for 204s and `application/octet-stream` bodies respectively.
public protocol APIResponse: Sendable {
    static func decode(_ data: Data, using decoder: JSONDecoder) throws -> Self
}

public extension APIResponse where Self: Decodable {
    static func decode(_ data: Data, using decoder: JSONDecoder) throws -> Self {
        try decoder.decode(Self.self, from: data)
    }
}

/// A response whose body is irrelevant (204 No Content and friends).
public struct Empty: APIResponse, Hashable {
    public init() {}

    public static func decode(_ data: Data, using decoder: JSONDecoder) -> Empty {
        Empty()
    }
}

/// Bytes as received, for encrypted blob downloads.
public struct RawResponse: APIResponse, Hashable {
    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public static func decode(_ data: Data, using decoder: JSONDecoder) -> RawResponse {
        RawResponse(data: data)
    }
}

/// One REST route (PROTOCOL.md §1). Endpoints are plain values so each route is declared once, next to
/// its DTOs, and the client stays generic.
public protocol Endpoint: Sendable {
    associatedtype Response: APIResponse

    /// Relative to `/api/v1`, without a leading slash (for example `auth/login`).
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem] { get }
    var body: RequestBody { get }
    /// False only for the auth routes that mint tokens.
    var requiresAuth: Bool { get }
    var transferMode: TransferMode { get }
}

public extension Endpoint {
    var query: [URLQueryItem] { [] }
    var body: RequestBody { .none }
    var requiresAuth: Bool { true }
    var transferMode: TransferMode { .buffered }
}
