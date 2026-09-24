import Foundation

/// Which inbox the app is showing. `decoy` is entered with the duress PIN and looks like an ordinary,
/// slightly dull messenger: the point is that someone forcing the phone open finds nothing worth
/// pressing for, and nothing on screen hints that another mode exists.
public enum AppLockMode: String, Hashable, Codable, Sendable, CaseIterable {
    case real
    case decoy

    public var isDecoy: Bool {
        self == .decoy
    }
}
