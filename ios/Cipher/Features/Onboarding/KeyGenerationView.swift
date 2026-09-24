import CipherCore
import CipherDesign
import SwiftUI

/// Runs the real identity bootstrap while telling its three-step story, then decrypts a confirmation
/// line before handing over to the inbox. Conflicts and failures stay on this screen with a way out.
struct KeyGenerationView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.xl) {
            header
            SectionCard {
                VStack(alignment: .leading, spacing: CipherSpacing.lg) {
                    ForEach(KeyBootstrapStep.allCases, id: \.self) { step in
                        KeyBootstrapStepRow(step: step, state: stepState(step))
                    }
                }
            }
            footer
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            Spacer(minLength: 0)
        }
        .padding(CipherSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CipherColor.background.ignoresSafeArea())
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: session.keyBootstrap)
        .task { await session.bootstrapIdentity() }
        .onChange(of: session.keyBootstrap, initial: true) { _, bootstrap in
            if case .completed = bootstrap { revealed = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            ShieldBadge(state: .verified, size: 28)
            Text(String(localized: "keygen.title", defaultValue: "Creating your identity"))
                .font(CipherTypography.title)
                .foregroundStyle(CipherColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "keygen.subtitle", defaultValue: "Your keys never leave this device."))
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch session.keyBootstrap {
        case .idle, .running:
            Text(String(localized: "keygen.running.hint", defaultValue: "This takes a moment the first time."))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
        case .completed(let bundle):
            KeyReadyView(bundle: bundle, revealed: revealed) {
                Task {
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 600))
                    await session.completeKeyBootstrap()
                }
            }
        case .conflict:
            KeyConflictCard(
                onRotate: { Task { await session.rotateIdentity() } },
                onSignOut: { Task { await session.signOut() } }
            )
        case .failed(let problem):
            VStack(spacing: CipherSpacing.md) {
                ProblemBanner(problem: problem)
                CipherButton(String(localized: "keygen.retry", defaultValue: "Try again"), systemImage: "arrow.clockwise") {
                    Task { await session.retryBootstrap() }
                }
                CipherButton(String(localized: "keygen.signOut", defaultValue: "Sign out"), variant: .ghost) {
                    Task { await session.signOut() }
                }
            }
        }
    }

    private func stepState(_ step: KeyBootstrapStep) -> KeyStepState {
        switch session.keyBootstrap {
        case .idle:
            .pending
        case .running(let current):
            step.rawValue < current.rawValue ? .done : (step == current ? .active : .pending)
        case .completed:
            .done
        case .conflict, .failed:
            step == .publishing ? .blocked : .done
        }
    }
}

/// The completion beat: a sentence decrypting into place over a mono peek at the published key.
struct KeyReadyView: View {
    let bundle: PublicKeyBundle
    let revealed: Bool
    let onRevealed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            DecryptText(
                String(localized: "keygen.ready", defaultValue: "Your identity is ready"),
                reveal: revealed,
                duration: 0.7,
                onCompleted: onRevealed
            )
                .font(CipherTypography.headline)
                .foregroundStyle(CipherColor.textPrimary)
            Text(String(localized: "keygen.ready.version", defaultValue: "Public key version") + " \(bundle.version)")
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
            Text(bundle.identityKey.base64EncodedString())
                .font(CipherTypography.monoSmall)
                .foregroundStyle(CipherColor.glyph)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel(String(localized: "keygen.ready.keyLabel", defaultValue: "Identity public key"))
        }
    }
}

#Preview("Publishing") {
    KeyGenerationView()
        .previewEnvironment(
            AppContainer.mock(signedInAs: Fixtures.alice, keysPublished: false),
            state: .bootstrappingKeys(Fixtures.session(for: Fixtures.alice))
        )
}

#Preview("Conflict") {
    KeyGenerationView()
        .previewEnvironment(
            AppContainer.mock(signedInAs: Fixtures.alice, keysPublished: false, keyUpload: .conflict),
            state: .bootstrappingKeys(Fixtures.session(for: Fixtures.alice))
        )
}
