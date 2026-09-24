import CipherCore
import CipherDesign
import Foundation
import Observation
import SwiftUI

/// Owns the visible sign-in state and the identity bootstrap that follows every authentication.
///
/// The state machine is deliberately small: `restoring` (reading the Keychain) → `signedOut` or an
/// authenticated state; authenticated means `bootstrappingKeys` until this device's public keys are
/// known to be on the relay, then `ready`. Keeping "authenticated but keys unpublished" as its own state
/// is what makes the 409 "keys exist on another device" case impossible to skip past.
@MainActor
@Observable
final class AppSession {
    enum State: Hashable {
        case restoring
        case signedOut
        case bootstrappingKeys(Session)
        case ready(Session)
    }

    /// Progress of the identity bootstrap shown by `KeyGenerationView`.
    enum KeyBootstrap: Hashable {
        case idle
        case running(KeyBootstrapStep)
        case completed(PublicKeyBundle)
        /// The relay holds different keys for this account; only an explicit rotation can proceed.
        case conflict
        case failed(PresentableProblem)
    }

    private(set) var state: State
    private(set) var keyBootstrap: KeyBootstrap = .idle
    private(set) var isSigningOut = false

    /// Fired once per transition into `ready`; the integrator starts the messaging stack here.
    var onAuthenticated: @MainActor (Session) async -> Void = { _ in }
    /// Fired once per transition out of an authenticated state; tear down account-scoped work here.
    var onSignedOut: @MainActor () async -> Void = {}

    @ObservationIgnored private let container: AppContainer
    /// Minimum time each bootstrap step stays on screen so the three-step story reads, even when the
    /// real work takes milliseconds. Zero in previews that need to finish immediately.
    @ObservationIgnored private let stepDwell: Duration

    init(container: AppContainer, initialState: State = .restoring, stepDwell: Duration = .milliseconds(650)) {
        self.container = container
        self.state = initialState
        self.stepDwell = stepDwell
    }

    var session: Session? {
        switch state {
        case .bootstrappingKeys(let session), .ready(let session): session
        case .restoring, .signedOut: nil
        }
    }

    var currentUser: User? { session?.user }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    // MARK: Restore & authenticate

    func restore() async {
        guard case .restoring = state else { return }
        do {
            guard let stored = try await container.sessionStore.load() else {
                state = .signedOut
                return
            }
            await enterAuthenticated(stored)
        } catch {
            AppLog.session.error("restore failed: \(String(describing: type(of: error)), privacy: .public)")
            state = .signedOut
        }
    }

    func register(username: String, password: String, displayName: String?) async throws {
        let session = try await container.authGateway.register(username: username, password: password, displayName: displayName)
        try await container.sessionStore.save(session)
        AppLog.session.info("registered \(session.user.id.description, privacy: .public)")
        await enterAuthenticated(session)
    }

    func login(username: String, password: String) async throws {
        let session = try await container.authGateway.login(username: username, password: password)
        try await container.sessionStore.save(session)
        AppLog.session.info("logged in \(session.user.id.description, privacy: .public)")
        await enterAuthenticated(session)
    }

    private func enterAuthenticated(_ session: Session) async {
        let published = container.publicationRegistry.hasPublished(session.user.id)
        let hasKeys = (try? await container.identityKeyStore.hasIdentity()) ?? false
        if published, hasKeys {
            await becomeReady(session)
        } else {
            keyBootstrap = .idle
            state = .bootstrappingKeys(session)
        }
    }

    private func becomeReady(_ session: Session) async {
        state = .ready(session)
        await onAuthenticated(session)
        await container.realtimeLifecycle.sessionDidBecomeReady()
    }

    // MARK: Identity bootstrap

    /// Creates keys if missing and publishes the public halves, pacing the visible steps.
    func bootstrapIdentity() async {
        guard case .bootstrappingKeys(let session) = state, canStartBootstrap else { return }
        keyBootstrap = .running(.generating)
        let dwell = stepDwell
        do {
            let outcome = try await container.identityBootstrapper.run { [weak self] step in
                await self?.show(step: step)
                try? await Task.sleep(for: dwell)
            }
            switch outcome {
            case .published(let bundle):
                container.publicationRegistry.markPublished(session.user.id)
                keyBootstrap = .completed(bundle)
                container.haptics.play(.verified)
            case .conflict:
                keyBootstrap = .conflict
                container.haptics.play(.warning)
            }
        } catch {
            AppLog.identity.error("bootstrap failed: \(String(describing: type(of: error)), privacy: .public)")
            keyBootstrap = .failed(PresentableProblem(error: error))
        }
    }

    /// Resolves a conflict by replacing the relay's keys with fresh ones (version + 1).
    func rotateIdentity() async {
        guard case .bootstrappingKeys(let session) = state, case .conflict = keyBootstrap else { return }
        do {
            for step in KeyBootstrapStep.allCases {
                keyBootstrap = .running(step)
                try await Task.sleep(for: stepDwell)
            }
            let bundle = try await container.identityBootstrapper.rotate()
            container.publicationRegistry.markPublished(session.user.id)
            keyBootstrap = .completed(bundle)
            container.haptics.play(.keyChanged)
        } catch {
            AppLog.identity.error("rotation failed: \(String(describing: type(of: error)), privacy: .public)")
            keyBootstrap = .failed(PresentableProblem(error: error))
        }
    }

    func retryBootstrap() async {
        guard case .failed = keyBootstrap else { return }
        keyBootstrap = .idle
        await bootstrapIdentity()
    }

    /// Called by the key screen once its reveal animation has played, so the transition to the inbox
    /// never cuts the story short.
    func completeKeyBootstrap() async {
        guard case .bootstrappingKeys(let session) = state, case .completed = keyBootstrap else { return }
        await becomeReady(session)
    }

    private var canStartBootstrap: Bool {
        switch keyBootstrap {
        case .idle, .failed: true
        case .running, .completed, .conflict: false
        }
    }

    private func show(step: KeyBootstrapStep) {
        keyBootstrap = .running(step)
    }

    // MARK: Sign out & lifecycle

    /// Revokes the refresh token when the relay is reachable and always clears the local session:
    /// sign-out must succeed offline, and a token that outlives the session expires on its own.
    func signOut() async {
        guard let session else {
            state = .signedOut
            return
        }
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await container.authGateway.logout(refreshToken: session.refreshToken)
        } catch {
            AppLog.session.notice("logout not acknowledged: \(String(describing: type(of: error)), privacy: .public)")
        }
        do {
            try await container.sessionStore.clear()
        } catch {
            AppLog.session.error("session clear failed: \(String(describing: type(of: error)), privacy: .public)")
        }
        await endSession()
    }

    /// Consumes refresh outcomes from the token provider for as long as the root view lives.
    func observeSessionEvents() async {
        for await event in container.sessionEvents.events {
            switch event {
            case .refreshed(let renewed):
                adopt(renewed)
            case .invalidated:
                container.toastCenter.show(
                    String(localized: "session.expired.toast", defaultValue: "Your session expired. Please sign in again."),
                    style: .warning,
                    systemImage: "clock.badge.exclamationmark"
                )
                await endSession()
            }
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isReady else { return }
        let lifecycle = container.realtimeLifecycle
        switch phase {
        case .active:
            Task { await lifecycle.applicationDidBecomeActive() }
        case .background:
            Task { await lifecycle.applicationDidEnterBackground() }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func adopt(_ renewed: Session) {
        switch state {
        case .ready: state = .ready(renewed)
        case .bootstrappingKeys: state = .bootstrappingKeys(renewed)
        case .restoring, .signedOut: break
        }
    }

    private func endSession() async {
        state = .signedOut
        keyBootstrap = .idle
        container.router.popToRoot()
        await container.realtimeLifecycle.sessionDidEnd()
        await onSignedOut()
        AppLog.session.info("session ended")
    }
}
