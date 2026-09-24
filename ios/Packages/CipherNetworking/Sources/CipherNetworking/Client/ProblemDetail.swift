import Foundation

/// RFC 7807 `application/problem+json` body as the relay emits it (PROTOCOL.md §5). `correlationId` is
/// the relay's extension and the one value worth surfacing in a support screen: it lets an operator find
/// the failing request in relay logs without the client ever logging request bodies.
public struct ProblemDetail: Hashable, Codable, Sendable {
    public static let typePrefix = "urn:cipher:problem:"

    public var type: String
    public var title: String?
    public var status: Int?
    public var detail: String?
    public var instance: String?
    public var correlationId: String?

    public init(
        type: String,
        title: String? = nil,
        status: Int? = nil,
        detail: String? = nil,
        instance: String? = nil,
        correlationId: String? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
        self.correlationId = correlationId
    }

    /// The `<slug>` of `urn:cipher:problem:<slug>`, or the raw type for foreign problem documents.
    public var slug: String {
        type.hasPrefix(Self.typePrefix) ? String(type.dropFirst(Self.typePrefix.count)) : type
    }

    /// Typed view of the slug so callers switch on cases instead of comparing strings.
    public var kind: ProblemKind {
        ProblemKind(rawValue: slug) ?? .unknown
    }

    /// The most specific human-readable text the relay provided.
    public var message: String? {
        detail ?? title
    }
}

/// Every problem type the relay defines (PROTOCOL.md §5). `unknown` covers relay versions newer than
/// this client rather than failing to decode the error at all.
public enum ProblemKind: String, Hashable, Sendable, CaseIterable {
    case validation
    case invalidCredentials = "invalid-credentials"
    case invalidRefreshToken = "invalid-refresh-token"
    case unauthorized
    case notAParticipant = "not-a-participant"
    case userNotFound = "user-not-found"
    case keysNotRegistered = "keys-not-registered"
    case conversationNotFound = "conversation-not-found"
    case blobNotFound = "blob-not-found"
    case usernameTaken = "username-taken"
    case keysAlreadyRegistered = "keys-already-registered"
    case payloadTooLarge = "payload-too-large"
    case rateLimited = "rate-limited"
    case internalError = "internal"
    case unknown
}
