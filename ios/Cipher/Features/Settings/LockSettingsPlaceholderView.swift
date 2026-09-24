import CipherDesign
import SwiftUI

/// Destination of `Route.lockSettings` until the app-lock feature lands; the integrator replaces this
/// view and keeps the Settings row that navigates here.
struct LockSettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            EmptyStateView(
                icon: "faceid",
                title: String(localized: "lock.placeholder.title", defaultValue: "App lock"),
                message: String(
                    localized: "lock.placeholder.message",
                    defaultValue: "PIN and Face ID protection arrive with the security features."
                )
            )
        }
        .navigationTitle(String(localized: "lock.placeholder.title", defaultValue: "App lock"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LockSettingsPlaceholderView()
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
