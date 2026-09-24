import Foundation

/// Client-side mirror of the relay's registration rules (PROTOCOL.md §1.1), so a person learns about a
/// bad username while typing instead of after a round trip. The relay still validates; this only
/// decides what the form shows and whether the submit button is enabled.
enum AuthValidation {
    static let usernameLength = 3...32
    static let passwordLength = 8...128
    static let displayNameMaxLength = 64

    enum UsernameIssue: Hashable, Sendable {
        case empty, tooShort, tooLong, invalidCharacters

        var message: String {
            switch self {
            case .empty:
                String(localized: "auth.validation.username.empty", defaultValue: "Choose a username.")
            case .tooShort:
                String(localized: "auth.validation.username.short", defaultValue: "At least 3 characters.")
            case .tooLong:
                String(localized: "auth.validation.username.long", defaultValue: "At most 32 characters.")
            case .invalidCharacters:
                String(localized: "auth.validation.username.chars", defaultValue: "Lowercase letters, digits and underscores only.")
            }
        }
    }

    enum PasswordIssue: Hashable, Sendable {
        case empty, tooShort, tooLong

        var message: String {
            switch self {
            case .empty:
                String(localized: "auth.validation.password.empty", defaultValue: "Enter a password.")
            case .tooShort:
                String(localized: "auth.validation.password.short", defaultValue: "At least 8 characters.")
            case .tooLong:
                String(localized: "auth.validation.password.long", defaultValue: "At most 128 characters.")
            }
        }
    }

    enum DisplayNameIssue: Hashable, Sendable {
        case tooLong

        var message: String {
            String(localized: "auth.validation.displayName.long", defaultValue: "At most 64 characters.")
        }
    }

    /// Usernames are compared case-insensitively by people but stored lowercase by the relay's pattern,
    /// so the form lowercases before validating rather than rejecting a capital letter.
    static func normalizedUsername(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func username(_ raw: String) -> UsernameIssue? {
        let value = normalizedUsername(raw)
        guard !value.isEmpty else { return .empty }
        guard value.count >= usernameLength.lowerBound else { return .tooShort }
        guard value.count <= usernameLength.upperBound else { return .tooLong }
        let allowed = value.unicodeScalars.allSatisfy { scalar in
            scalar == "_" || ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
        }
        return allowed ? nil : .invalidCharacters
    }

    static func password(_ value: String) -> PasswordIssue? {
        guard !value.isEmpty else { return .empty }
        guard value.count >= passwordLength.lowerBound else { return .tooShort }
        guard value.count <= passwordLength.upperBound else { return .tooLong }
        return nil
    }

    static func displayName(_ raw: String) -> DisplayNameIssue? {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).count <= displayNameMaxLength ? nil : .tooLong
    }
}
