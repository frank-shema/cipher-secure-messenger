import CipherCore
import Foundation
import Observation

/// Form state for `AuthView`. Validation runs on every keystroke but issues are only surfaced for
/// fields the person has left (or after a submit attempt), so an empty form is not a wall of red.
@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable, Hashable, Sendable {
        case register
        case login

        var title: String {
            switch self {
            case .register: String(localized: "auth.mode.register", defaultValue: "Register")
            case .login: String(localized: "auth.mode.login", defaultValue: "Log in")
            }
        }
    }

    var mode: Mode
    var username = ""
    var displayName = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var problem: PresentableProblem?
    private(set) var touched: Set<Field> = []

    enum Field: Hashable, Sendable {
        case username, displayName, password
    }

    @ObservationIgnored private let session: AppSession

    init(session: AppSession, mode: Mode = .register) {
        self.session = session
        self.mode = mode
    }

    var usernameIssue: AuthValidation.UsernameIssue? { AuthValidation.username(username) }
    var passwordIssue: AuthValidation.PasswordIssue? { AuthValidation.password(password) }
    var displayNameIssue: AuthValidation.DisplayNameIssue? { mode == .register ? AuthValidation.displayName(displayName) : nil }

    var isValid: Bool {
        usernameIssue == nil && passwordIssue == nil && displayNameIssue == nil
    }

    func shows(_ field: Field) -> Bool {
        touched.contains(field)
    }

    func markTouched(_ field: Field) {
        touched.insert(field)
    }

    func switchMode(to newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        problem = nil
        touched.remove(.displayName)
    }

    func dismissProblem() {
        problem = nil
    }

    /// Submits the form. On success `AppSession` moves on and this screen is torn down; on failure the
    /// relay's problem document is shown inline and the fields keep their values.
    func submit() async {
        touched = [.username, .password, .displayName]
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        problem = nil
        defer { isSubmitting = false }
        let user = AuthValidation.normalizedUsername(username)
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .register:
                try await session.register(username: user, password: password, displayName: name.isEmpty ? nil : name)
            case .login:
                try await session.login(username: user, password: password)
            }
            AppLog.onboarding.info("auth succeeded mode=\(self.mode.rawValue, privacy: .public)")
        } catch {
            let kind = String(describing: type(of: error))
            AppLog.onboarding.notice("auth failed mode=\(self.mode.rawValue, privacy: .public) error=\(kind, privacy: .public)")
            problem = PresentableProblem(error: error)
        }
    }
}
