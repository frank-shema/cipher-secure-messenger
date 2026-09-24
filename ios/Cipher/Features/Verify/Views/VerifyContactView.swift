import CipherCore
import CipherDesign
import SwiftUI

/// `Route.verify(UserID)`: the emoji safety fingerprint, the safety number, this account's QR code and
/// the scanner, plus the key-change review when the contact's keys were replaced.
struct VerifyContactView: View {
    @State private var viewModel: VerifyContactViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: VerifyContactViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// The initializer the router calls: builds and owns the view model for `userId`.
    init(userId: UserID, dependencies: VerifyDependencies, haptics: any HapticEngine) {
        self.init(viewModel: VerifyContactViewModel(userId: userId, dependencies: dependencies, haptics: haptics))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CipherSpacing.xl) {
                if let keyChange = viewModel.keyChange, viewModel.isReviewingKeyChange {
                    KeyChangeReviewView(
                        info: keyChange,
                        isBusy: viewModel.isBusy,
                        onVerifyAgain: viewModel.beginVerifyAgain,
                        onTrustNewKeys: { Task { await viewModel.trustNewKeys() } }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    verification
                }
            }
            .padding(.horizontal, CipherSpacing.lg)
            .padding(.vertical, CipherSpacing.lg)
            .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: viewModel.isReviewingKeyChange)
            .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: viewModel.outcome)
        }
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(String(localized: "verify.title", defaultValue: "Verify keys"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.run() }
        .sheet(isPresented: $viewModel.isScannerPresented) {
            QRScannerScreen(contactName: viewModel.contactName, onCode: viewModel.handleScanned)
        }
        .alert(
            String(localized: "verify.error.title", defaultValue: "Could not update trust"),
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.dismissError() } })
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var verification: some View {
        if let outcome = viewModel.outcome {
            VerificationOutcomeCard(outcome: outcome, contactName: viewModel.contactName, onDismiss: viewModel.dismissOutcome)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        if let contact = viewModel.contact {
            VerifyHeroSection(contact: contact, fingerprint: viewModel.fingerprint, phase: viewModel.phase)
        }
        VerifyStatusCard(
            trust: viewModel.trust,
            contactName: viewModel.contactName,
            isBusy: viewModel.isBusy,
            canConfirm: viewModel.phase == .ready,
            onConfirm: { Task { await viewModel.confirmReadAloud() } },
            onReviewKeyChange: { viewModel.isReviewingKeyChange = true }
        )
        if let number = viewModel.safetyNumber {
            SafetyNumberGrid(number: number)
        }
        VerifyQRSection(payload: viewModel.qrPayload, contactName: viewModel.contactName, onScan: viewModel.presentScanner)
    }
}

#Preview("Unverified") {
    NavigationStack {
        VerifyContactView(viewModel: VerifyPreviews.viewModel(for: .unverified))
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}

#Preview("Verified") {
    NavigationStack {
        VerifyContactView(viewModel: VerifyPreviews.viewModel(for: .verified))
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}

#Preview("Key changed") {
    NavigationStack {
        VerifyContactView(viewModel: VerifyPreviews.viewModel(for: .keyChanged))
    }
    .previewEnvironment(AppContainer.mock(signedInAs: Fixtures.alice), state: .ready(Fixtures.session(for: Fixtures.alice)))
}
