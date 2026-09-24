import CipherDesign
import SwiftUI

/// Switches between the onboarding, key generation and signed-in experiences on `AppSession.state`.
/// Every branch gets a full-screen crossfade so state changes read as one app, not four launches.
///
/// The lock screen sits above everything and the privacy guard wraps everything, so no message can
/// render outside either: a PIN prompt is never overlaid on readable content, and the app-switcher
/// snapshot only ever shows the curtain.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            content
                .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
            if isLockVisible {
                LockView(lock: container.appLock)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: session.state)
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isLockVisible)
        .privacyGuard(container.flipToHide)
        .task { await session.restore() }
        .task { await session.observeSessionEvents() }
        .onChange(of: scenePhase) { _, phase in
            session.handleScenePhase(phase)
            container.appLock.handleScenePhase(phase)
        }
        .onChange(of: container.appLock.mode) { _, mode in
            Task { await container.messaging.lockModeDidChange(mode) }
        }
        .toastHost()
    }

    /// Onboarding stays reachable without a PIN: the lock protects an account, not the sign-in form.
    private var isLockVisible: Bool {
        container.appLock.isLocked && session.state != .signedOut
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .restoring:
            RestoringView()
        case .signedOut:
            OnboardingFlowView()
        case .bootstrappingKeys:
            KeyGenerationView()
        case .ready:
            MainNavigationView()
        }
    }
}

/// The signed-in navigation shell: one stack whose path the shared `Router` owns.
struct MainNavigationView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            InboxScreen()
                .navigationDestination(for: Route.self) { route in
                    RouteDestinationView(route: route)
                }
        }
        .tint(CipherColor.accent)
    }
}

/// Shown for the few hundred milliseconds it takes to read the Keychain. It mirrors the launch screen
/// so the hand-off from the system splash is invisible.
struct RestoringView: View {
    var body: some View {
        VStack(spacing: CipherSpacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(CipherGradient.primaryAction)
                .accessibilityHidden(true)
            ProgressView()
                .tint(CipherColor.accent)
                .accessibilityLabel(String(localized: "root.restoring", defaultValue: "Restoring your session"))
        }
    }
}

#Preview("Signed out") {
    RootView()
        .previewEnvironment(AppContainer.mock())
}

#Preview("Ready") {
    RootView()
        .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
