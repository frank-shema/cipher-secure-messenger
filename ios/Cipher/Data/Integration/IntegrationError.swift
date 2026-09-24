import Foundation

/// Raised when a composition-root factory has no concrete implementation for the requested graph.
/// Surfacing this as a typed, localized error (instead of a crash) keeps the shell usable and makes
/// the missing piece obvious in a banner; the production container never hits it.
enum IntegrationError: Error, LocalizedError, Hashable, Sendable {
    case notWired(component: String)

    var errorDescription: String? {
        switch self {
        case .notWired(let component):
            String(localized: "error.integration.notWired", defaultValue: "This build is missing a component:")
                + " \(component)"
        }
    }
}
