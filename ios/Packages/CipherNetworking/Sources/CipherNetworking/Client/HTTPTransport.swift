import Foundation

/// The thin seam between `APIClient` and URLSession. Tests substitute a fake; production uses
/// `URLSessionTransport`. All three calls return the full body so the client validates responses the
/// same way regardless of how the bytes moved.
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, from body: Data, progress: TransferProgress?) async throws -> (Data, URLResponse)
    func download(for request: URLRequest, progress: TransferProgress?) async throws -> (Data, URLResponse)
}

/// URLSession-backed transport. Uploads report progress through a per-task delegate; downloads stream
/// bytes so progress can be derived from `Content-Length` without a temporary file.
public struct URLSessionTransport: HTTPTransport {
    /// Progress is reported at most once per this many bytes so a 25 MiB transfer does not flood the UI.
    static let progressGranularity = 32 * 1_024

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// A session tuned for the relay: no cookies, no cache (responses are either secrets or ciphertext),
    /// and a request timeout generous enough for a LAN relay under load.
    public static func makeSession(requestTimeout: TimeInterval = 30, resourceTimeout: TimeInterval = 300) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    public func upload(for request: URLRequest, from body: Data, progress: TransferProgress?) async throws -> (Data, URLResponse) {
        let delegate = progress.map(UploadProgressDelegate.init)
        let result = try await session.upload(for: request, from: body, delegate: delegate)
        progress?.report(1)
        return result
    }

    public func download(for request: URLRequest, progress: TransferProgress?) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        let expected = response.expectedContentLength
        var received = Data()
        if expected > 0, let capacity = Int(exactly: expected) {
            received.reserveCapacity(capacity)
        }
        var sinceLastReport = 0
        for try await byte in bytes {
            received.append(byte)
            sinceLastReport += 1
            if sinceLastReport >= Self.progressGranularity {
                sinceLastReport = 0
                progress?.report(completed: Int64(received.count), total: expected)
            }
        }
        progress?.report(1)
        return (received, response)
    }
}

/// Forwards URLSession's byte counts into a `TransferProgress`. The only state is one immutable
/// reference to a `Sendable` reporter, which is what makes the unchecked conformance sound.
final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: TransferProgress

    init(progress: TransferProgress) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        progress.report(completed: totalBytesSent, total: totalBytesExpectedToSend)
    }
}
