import CipherDesign
import SwiftUI

/// Welcome → Auth, in its own navigation stack so onboarding gets a native back gesture without
/// touching the signed-in `Router`.
struct OnboardingFlowView: View {
    enum Step: Hashable {
        case auth(AuthViewModel.Mode)
    }

    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { mode in
                path.append(.auth(mode))
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .auth(let mode):
                    AuthView(mode: mode)
                }
            }
        }
        .tint(CipherColor.accent)
    }
}

#Preview {
    OnboardingFlowView()
        .previewEnvironment(AppContainer.mock())
}
