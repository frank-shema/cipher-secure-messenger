import Foundation

/// Turns an HTTP response into either "proceed to decode" or a classified `APIError`, parsing the
/// relay's RFC 7807 body along the way. Kept separate from the client so it is a pure function of
/// `(response, data, now)`.
struct ResponseValidator: Sendable {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder) {
        self.decoder = decoder
    }

    func validate(_ response: HTTPURLResponse, data: Data, now: Date) throws(APIError) {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw .unauthorized(problem(in: response, data: data))
        case 413:
            throw .payloadTooLarge(problem(in: response, data: data))
        case 429:
            let retryAfter = Self.retryAfter(from: response.value(forHTTPHeaderField: "Retry-After"), now: now)
            throw .rateLimited(retryAfter: retryAfter, problem: problem(in: response, data: data))
        default:
            throw .http(status: response.statusCode, problem: problem(in: response, data: data))
        }
    }

    /// Parses a problem document when the content type says so, and also when a proxy rewrote the
    /// content type but left the JSON intact. Anything else yields nil rather than a decoding error,
    /// because the status code alone is still actionable.
    func problem(in response: HTTPURLResponse, data: Data) -> ProblemDetail? {
        guard !data.isEmpty else { return nil }
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let looksLikeJSON = contentType.contains("json") || data.first == UInt8(ascii: "{")
        guard looksLikeJSON, let problem = try? decoder.decode(ProblemDetail.self, from: data) else { return nil }
        return problem
    }

    /// `Retry-After` is either delta-seconds or an HTTP-date (RFC 9110 §10.2.3).
    static func retryAfter(from header: String?, now: Date) -> TimeInterval? {
        guard let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty else { return nil }
        if let seconds = TimeInterval(header) {
            return max(0, seconds)
        }
        guard let date = httpDateFormatter.date(from: header) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        return formatter
    }()
}
