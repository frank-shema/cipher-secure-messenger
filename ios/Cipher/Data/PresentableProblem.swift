import Foundation

/// Adopted by errors that carry an RFC 7807 problem (PROTOCOL.md §5) so the UI can show the relay's own
/// `title`/`detail` and a correlation id support can grep for. `CipherNetworking.APIError` adopts this
/// in `ProductionFactories`; the mock gateways adopt it directly.
protocol ProblemPresentable: Error {
    /// `urn:cipher:problem:<slug>`, when the relay sent one.
    var problemType: String? { get }
    var problemStatus: Int? { get }
    var problemTitle: String? { get }
    var problemDetail: String? { get }
    var correlationId: String? { get }
}

/// What a banner shows for any failure: a short title, a sentence of detail and, when the relay supplied
/// one, the correlation id. Built from a `ProblemPresentable` first, then `LocalizedError`, then a generic
/// fallback, so no code path ever surfaces a bare `Error` description to a person.
struct PresentableProblem: Hashable, Sendable, Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let correlationId: String?

    init(title: String, detail: String, correlationId: String? = nil) {
        self.title = title
        self.detail = detail
        self.correlationId = correlationId
    }

    init(error: any Error) {
        if let problem = error as? any ProblemPresentable {
            self.title = problem.problemTitle
                ?? String(localized: "error.generic.title", defaultValue: "Something went wrong")
            self.detail = problem.problemDetail
                ?? (error as? any LocalizedError)?.errorDescription
                ?? String(localized: "error.generic.detail", defaultValue: "Please try again.")
            self.correlationId = problem.correlationId
            return
        }
        self.title = String(localized: "error.generic.title", defaultValue: "Something went wrong")
        self.detail = (error as? any LocalizedError)?.errorDescription
            ?? String(localized: "error.generic.detail", defaultValue: "Please try again.")
        self.correlationId = nil
    }
}
