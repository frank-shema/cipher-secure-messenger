import CipherCore
import Foundation

/// Every way a REST call can fail, already classified so callers never inspect status codes or
/// `URLError` codes themselves. `isRetryable` feeds Core's `FailureClassifier`, which decides whether a
/// message stays in the outbox or is shown as failed.
public enum APIError: Error, LocalizedError, Equatable, Sendable {
    /// The endpoint could not be turned into a URL (bad base URL or path).
    case invalidURL
    /// The request body could not be encoded; carries the encoder's description for diagnostics.
    case encoding(String)
    /// The network layer failed before an HTTP response arrived.
    case transport(URLError)
    /// The device has no route to the network at all.
    case offline
    /// The request was cancelled by the caller's task.
    case cancelled
    /// A non-2xx status not covered by a more specific case.
    case http(status: Int, problem: ProblemDetail?)
    /// A 2xx body that did not match the expected shape.
    case decoding(String)
    /// 401 after the single refresh-and-retry, or no session to authenticate with.
    case unauthorized(ProblemDetail?)
    /// 429; `retryAfter` comes from the `Retry-After` header when the relay sent one.
    case rateLimited(retryAfter: TimeInterval?, problem: ProblemDetail?)
    /// 413, or a body the client refused to send because it exceeds the relay's limit.
    case payloadTooLarge(ProblemDetail?)

    /// The relay's problem document when there is one, so UI can show `detail` or `correlationId`.
    public var problem: ProblemDetail? {
        switch self {
        case let .http(_, problem), let .unauthorized(problem), let .payloadTooLarge(problem):
            problem
        case let .rateLimited(_, problem):
            problem
        case .invalidURL, .encoding, .transport, .offline, .cancelled, .decoding:
            nil
        }
    }

    public var statusCode: Int? {
        switch self {
        case let .http(status, _): status
        case .unauthorized: 401
        case .payloadTooLarge: 413
        case .rateLimited: 429
        case .invalidURL, .encoding, .transport, .offline, .cancelled, .decoding: nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            NetStrings.localized("error.api.invalidURL", default: "The server address is not valid.")
        case .encoding:
            NetStrings.localized("error.api.encoding", default: "The request could not be prepared.")
        case .transport:
            NetStrings.localized("error.api.transport", default: "The server could not be reached.")
        case .offline:
            NetStrings.localized("error.api.offline", default: "You appear to be offline.")
        case .cancelled:
            NetStrings.localized("error.api.cancelled", default: "The request was cancelled.")
        case let .http(_, problem):
            problem?.message ?? NetStrings.localized("error.api.http", default: "The server returned an error.")
        case .decoding:
            NetStrings.localized("error.api.decoding", default: "The server sent an unexpected response.")
        case let .unauthorized(problem):
            problem?.message ?? NetStrings.localized("error.api.unauthorized", default: "Your session has expired. Please sign in again.")
        case .rateLimited:
            NetStrings.localized("error.api.rateLimited", default: "Too many requests. Please wait a moment and try again.")
        case let .payloadTooLarge(problem):
            problem?.message ?? NetStrings.localized("error.api.payloadTooLarge", default: "This is too large to send.")
        }
    }
}

extension APIError: RetryableError {
    /// Transient failures are worth an automatic retry; everything the client itself got wrong is not.
    public var isRetryable: Bool {
        switch self {
        case .offline, .cancelled, .rateLimited:
            true
        case let .transport(urlError):
            Self.retryableTransportCodes.contains(urlError.code)
        case let .http(status, _):
            status >= 500
        case .invalidURL, .encoding, .decoding, .unauthorized, .payloadTooLarge:
            false
        }
    }

    private static let retryableTransportCodes: Set<URLError.Code> = [
        .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed,
        .resourceUnavailable, .badServerResponse, .secureConnectionFailed
    ]

    /// Classifies a thrown transport error. Offline conditions get their own case because the UI treats
    /// "no network" (show a banner, keep the outbox) differently from "the relay is down".
    static func classify(_ error: any Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .transport(URLError(.unknown))
        }
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            return .offline
        case .cancelled:
            return .cancelled
        default:
            return .transport(urlError)
        }
    }
}
