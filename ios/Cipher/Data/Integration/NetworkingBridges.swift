import CipherCore
import CipherNetworking
import Foundation

/// The adapter's method shapes already match the networking protocol; declaring the conformance here
/// keeps `AuthTokenProviderAdapter` itself importable without the networking module.
extension AuthTokenProviderAdapter: AuthTokenProvider {}

/// Lets the UI show the relay's own RFC 7807 title/detail and correlation id for any REST failure,
/// instead of a generic sentence, without the feature layer importing the networking module.
extension APIError: ProblemPresentable {
    var problemType: String? { problem?.type }
    var problemStatus: Int? { statusCode }
    var problemTitle: String? { problem?.title }
    var problemDetail: String? { problem?.detail ?? errorDescription }
    var correlationId: String? { problem?.correlationId }
}
