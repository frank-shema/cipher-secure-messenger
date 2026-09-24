import CipherDesign
import SwiftUI

/// Register / log in. The view model is created once the environment session is available and then
/// owned by this screen for its whole lifetime, so typed text survives mode switches and errors.
struct AuthView: View {
    let mode: AuthViewModel.Mode
    @Environment(AppSession.self) private var session
    @State private var model: AuthViewModel?

    var body: some View {
        Group {
            if let model {
                AuthFormView(model: model)
            } else {
                CipherColor.background.ignoresSafeArea()
            }
        }
        .onAppear {
            if model == nil {
                model = AuthViewModel(session: session, mode: mode)
            }
        }
    }
}

struct AuthFormView: View {
    @Bindable var model: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CipherSpacing.xl) {
                header
                modePicker
                fields
                if let problem = model.problem {
                    ProblemBanner(problem: problem) { model.dismissProblem() }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                submit
            }
            .padding(.horizontal, CipherSpacing.xl)
            .padding(.vertical, CipherSpacing.lg)
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: model.mode)
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: model.problem)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(model.mode.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            Text(model.mode == .register
                ? String(localized: "auth.header.register", defaultValue: "Create your account")
                : String(localized: "auth.header.login", defaultValue: "Welcome back"))
                .font(CipherTypography.title)
                .foregroundStyle(CipherColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(model.mode == .register
                ? String(localized: "auth.subtitle.register", defaultValue: "A username is all the relay ever learns about you.")
                : String(localized: "auth.subtitle.login", defaultValue: "Your messages are only readable on your devices."))
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
        }
    }

    private var modePicker: some View {
        Picker(String(localized: "auth.mode.picker", defaultValue: "Register or log in"), selection: Binding(
            get: { model.mode },
            set: { model.switchMode(to: $0) }
        )) {
            ForEach(AuthViewModel.Mode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.md) {
            AuthFieldRow(issue: model.shows(.username) ? model.usernameIssue?.message : nil) {
                CipherTextField(title: String(localized: "auth.field.username", defaultValue: "Username"), text: $model.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.username)
            }
            .onChange(of: model.username) { _, _ in model.markTouched(.username) }
            if model.mode == .register {
                AuthFieldRow(issue: model.shows(.displayName) ? model.displayNameIssue?.message : nil) {
                    CipherTextField(
                        title: String(localized: "auth.field.displayName", defaultValue: "Display name (optional)"),
                        text: $model.displayName
                    )
                        .textContentType(.name)
                }
                .onChange(of: model.displayName) { _, _ in model.markTouched(.displayName) }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            AuthFieldRow(issue: model.shows(.password) ? model.passwordIssue?.message : nil) {
                CipherTextField(
                    title: String(localized: "auth.field.password", defaultValue: "Password"),
                    text: $model.password,
                    isSecure: true
                )
            }
            .onChange(of: model.password) { _, _ in model.markTouched(.password) }
        }
    }

    private var submit: some View {
        VStack(spacing: CipherSpacing.sm) {
            CipherButton(model.mode.title, systemImage: model.isSubmitting ? nil : "lock.open") {
                Task { await model.submit() }
            }
            .disabled(model.isSubmitting || !model.isValid)
            .overlay {
                if model.isSubmitting {
                    ProgressView().tint(Color(hex: 0x0B0F1A))
                }
            }
            .accessibilityHint(model.isValid
                ? String(localized: "auth.submit.hint.ready", defaultValue: "Submits the form")
                : String(localized: "auth.submit.hint.invalid", defaultValue: "Fix the highlighted fields first"))
            Text(String(localized: "auth.footnote", defaultValue: "Passwords are only used to sign in; they never protect your messages."))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Register") {
    NavigationStack {
        AuthView(mode: .register)
    }
    .previewEnvironment(AppContainer.mock())
}

#Preview("Login") {
    NavigationStack {
        AuthView(mode: .login)
    }
    .previewEnvironment(AppContainer.mock())
}
