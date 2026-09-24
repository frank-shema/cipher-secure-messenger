import CipherDesign
import SwiftUI

/// Account, relay address, identity keys, app lock hook, developer switches and sign-out.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @State private var model: SettingsViewModel?
    @State private var confirmingSignOut = false

    var body: some View {
        ScrollView {
            if let model {
                VStack(spacing: CipherSpacing.xl) {
                    if let user = session.currentUser {
                        SettingsAccountCard(user: user)
                    }
                    SettingsIdentitySection(model: model)
                    SettingsServerSection(model: model)
                    SettingsSecuritySection(showsAppLock: !isDecoy) {
                        router.navigate(to: .lockSettings)
                    }
                    #if DEBUG
                    if !isDecoy {
                        DemoBotSettingsSection(controller: container.demoBot) { id in
                            router.navigate(to: .conversation(id))
                        }
                    }
                    #endif
                    if !isDecoy {
                        signOut
                    }
                    Text(String(localized: "settings.version", defaultValue: "Cipher") + " " + model.appVersion)
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.textSecondary)
                        .accessibilityLabel(versionLabel + " " + model.appVersion)
                }
                .padding(.horizontal, CipherSpacing.lg)
                .padding(.vertical, CipherSpacing.lg)
                .task { await model.loadKeys() }
            }
        }
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if model == nil { model = SettingsViewModel(container: container) }
        }
        .confirmationDialog(
            String(localized: "settings.signOut.confirm.title", defaultValue: "Sign out of Cipher?"),
            isPresented: $confirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.signOut", defaultValue: "Sign out"), role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text(signOutMessage)
        }
    }

    /// The decoy inbox must not reveal that a lock exists, nor let a coerced person be signed out.
    private var isDecoy: Bool {
        container.messaging.isDecoy
    }

    private var signOut: some View {
        CipherButton(
            String(localized: "settings.signOut", defaultValue: "Sign out"),
            systemImage: "rectangle.portrait.and.arrow.right",
            variant: .destructive
        ) {
            confirmingSignOut = true
        }
        .disabled(session.isSigningOut)
    }
}

private extension SettingsView {
    var versionLabel: String {
        String(localized: "settings.version.label", defaultValue: "App version")
    }

    var signOutMessage: String {
        String(
            localized: "settings.signOut.confirm.message",
            defaultValue: "Your identity keys stay on this device so you can sign back in without rotating them."
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
    .toastHost()
}
