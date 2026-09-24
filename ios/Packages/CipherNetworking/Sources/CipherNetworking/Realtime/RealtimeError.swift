import Foundation

/// Every way the `/ws` channel can fail from a caller's point of view. Reconnection is automatic, so
/// most of these only surface from `send`, which refuses to queue frames on a dead socket: the caller
/// (typing indicators, acks) decides whether the frame still matters once the socket is back.
public enum RealtimeError: Error, LocalizedError, Hashable, Sendable {
    /// `send` was called while the socket is not open.
    case notConnected
    /// There is no session to authenticate the socket with.
    case notSignedIn
    /// The relay closed with 4001 and the session could not be refreshed.
    case authenticationRejected
    /// The relay closed with 4008.
    case rateLimited
    /// An outbound event could not be turned into a frame.
    case encoding(String)
    /// The socket failed below the frame layer; carries the transport's description for diagnostics.
    case transport(String)
    /// The relay closed the socket with the given code.
    case closed(code: Int)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            NetStrings.localized("error.realtime.notConnected", default: "Not connected to the server.")
        case .notSignedIn:
            NetStrings.localized("error.realtime.notSignedIn", default: "You are signed out.")
        case .authenticationRejected:
            NetStrings.localized("error.realtime.authenticationRejected", default: "Your session has expired. Please sign in again.")
        case .rateLimited:
            NetStrings.localized("error.realtime.rateLimited", default: "Too many requests. Please wait a moment and try again.")
        case .encoding:
            NetStrings.localized("error.realtime.encoding", default: "A realtime message could not be prepared.")
        case .transport:
            NetStrings.localized("error.realtime.transport", default: "The live connection was interrupted.")
        case .closed:
            NetStrings.localized("error.realtime.closed", default: "The live connection was closed by the server.")
        }
    }
}

/// Why a received frame could not become a `ServerEvent`. These never stop the stream: the client logs
/// the frame type and keeps reading, so one unknown event from a newer relay cannot silence the socket.
public enum RealtimeFrameError: Error, Hashable, Sendable {
    case malformed(String)
    case unsupportedVersion(Int)
    case unknownType(String)
}
