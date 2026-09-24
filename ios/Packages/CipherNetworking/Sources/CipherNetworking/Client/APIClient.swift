import CipherCore
import Foundation
import os

/// The one way REST bytes leave and enter the app. It is a value type because it has no state of its
/// own: coalescing refreshes belongs to `CoalescingAuthTokenProvider`, and connection pooling to the
/// transport. Every call gets a Bearer token when the endpoint needs one, a fresh `X-Correlation-Id`
/// so a relay operator can find it in their logs, and exactly one refresh-and-retry on 401. A second
/// 401 means the session is dead and is surfaced as `APIError.unauthorized` for the app to sign out.
public struct APIClient: Sendable {
    public static let correlationHeader = "X-Correlation-Id"

    private let configuration: APIConfiguration
    private let tokenProvider: any AuthTokenProvider
    private let transport: any HTTPTransport
    private let clock: any Clock
    private let correlationIds: any UUIDGenerator
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let validator: ResponseValidator

    public init(
        configuration: APIConfiguration,
        tokenProvider: any AuthTokenProvider,
        transport: any HTTPTransport = URLSessionTransport(session: URLSessionTransport.makeSession()),
        clock: any Clock = SystemClock(),
        correlationIds: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.clock = clock
        self.correlationIds = correlationIds
        self.encoder = WireJSON.makeEncoder()
        self.decoder = WireJSON.makeDecoder()
        self.validator = ResponseValidator(decoder: decoder)
    }

    /// Performs a request and decodes its response.
    public func send<E: Endpoint>(_ endpoint: E) async throws(APIError) -> E.Response {
        try await send(endpoint, progress: nil)
    }

    /// Performs a request, reporting transfer progress for `.upload` / `.download` endpoints. The
    /// progress stream is always finished, on success and on failure, so observers never hang.
    public func send<E: Endpoint>(_ endpoint: E, progress: TransferProgress?) async throws(APIError) -> E.Response {
        defer { progress?.finish() }
        let data = try await execute(endpoint, progress: progress, canRefresh: endpoint.requiresAuth)
        do {
            return try E.Response.decode(data, using: decoder)
        } catch {
            NetLog.api.error(
                "decoding failed for \(endpoint.path, privacy: .public): \(String(describing: type(of: error)), privacy: .public)"
            )
            throw .decoding(String(describing: error))
        }
    }

    // MARK: - Pipeline

    private func execute<E: Endpoint>(_ endpoint: E, progress: TransferProgress?, canRefresh: Bool) async throws(APIError) -> Data {
        var (request, body) = try makeRequest(for: endpoint)
        let correlationId = correlationIds.next().uuidString.lowercased()
        request.setValue(correlationId, forHTTPHeaderField: Self.correlationHeader)
        if endpoint.requiresAuth {
            request.setValue("Bearer \(try await currentToken())", forHTTPHeaderField: "Authorization")
        }

        let started = clock.now()
        let (data, response) = try await perform(request, body: body, mode: endpoint.transferMode, progress: progress)
        guard let http = response as? HTTPURLResponse else {
            throw .transport(URLError(.badServerResponse))
        }
        let elapsedMillis = Int(clock.now().timeIntervalSince(started) * 1_000)
        let route = "\(endpoint.method.rawValue) \(endpoint.path) -> \(http.statusCode) in \(elapsedMillis)ms"
        NetLog.api.debug("\(route, privacy: .public) cid=\(correlationId, privacy: .public)")

        do {
            try validator.validate(http, data: data, now: clock.now())
        } catch {
            if case let .unauthorized(problem) = error, canRefresh {
                NetLog.api.notice("401 on \(endpoint.path, privacy: .public); refreshing session once")
                _ = try await refreshedToken(after: problem)
                return try await execute(endpoint, progress: progress, canRefresh: false)
            }
            throw error
        }
        return data
    }

    private func perform(
        _ request: URLRequest,
        body: Data?,
        mode: TransferMode,
        progress: TransferProgress?
    ) async throws(APIError) -> (Data, URLResponse) {
        do {
            switch mode {
            case .buffered:
                return try await transport.data(for: request)
            case .upload:
                return try await transport.upload(for: request, from: body ?? Data(), progress: progress)
            case .download:
                return try await transport.download(for: request, progress: progress)
            }
        } catch {
            throw APIError.classify(error)
        }
    }

    // MARK: - Request construction

    private func makeRequest<E: Endpoint>(for endpoint: E) throws(APIError) -> (URLRequest, Data?) {
        let url = configuration.apiBaseURL.appending(path: endpoint.path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw .invalidURL
        }
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let resolved = components.url else {
            throw .invalidURL
        }

        var request = URLRequest(url: resolved)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json, application/problem+json", forHTTPHeaderField: "Accept")

        var body: Data?
        switch endpoint.body {
        case .none:
            break
        case let .json(value):
            do {
                body = try encoder.encode(value)
            } catch {
                throw .encoding(String(describing: error))
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case let .multipart(form):
            body = form.encoded()
            request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        }
        // Upload tasks take the body as a separate argument; setting `httpBody` there would be ignored.
        if endpoint.transferMode == .buffered {
            request.httpBody = body
        }
        return (request, body)
    }

    // MARK: - Tokens

    private func currentToken() async throws(APIError) -> String {
        do {
            guard let token = try await tokenProvider.accessToken() else {
                throw APIError.unauthorized(nil)
            }
            return token
        } catch {
            throw Self.classifyTokenFailure(error, problem: nil)
        }
    }

    private func refreshedToken(after problem: ProblemDetail?) async throws(APIError) -> String {
        do {
            return try await tokenProvider.refresh()
        } catch {
            throw Self.classifyTokenFailure(error, problem: problem)
        }
    }

    /// A token provider can fail for two very different reasons: the session is gone (sign out) or the
    /// refresh call itself hit the network (retry later). Only the transient kind keeps its identity.
    static func classifyTokenFailure(_ error: any Error, problem: ProblemDetail?) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        if FailureClassifier.isTransient(error) {
            return APIError.classify(error)
        }
        return .unauthorized(problem)
    }
}
