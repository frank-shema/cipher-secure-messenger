#if DEBUG
import CipherDesign
import SwiftUI

/// The only screen shown when the app is launched with `--self-test`. It narrates the steps so a
/// developer watching the simulator sees what a CI run is doing, then hands the verdict to
/// `DemoBotSelfTest.report`, which prints it and exits.
struct DemoBotSelfTestView: View {
    let command: DemoBotSelfTest.Command
    /// Off in previews, where exiting the process would kill the canvas.
    var exitsWhenFinished = true

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var runner: DemoBotSelfTestRunner?

    var body: some View {
        VStack(spacing: CipherSpacing.xl) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(CipherGradient.primaryAction)
                .accessibilityHidden(true)
            Text(String(localized: "demo.selftest.title", defaultValue: "Echo self-test"))
                .font(CipherTypography.headline)
                .foregroundStyle(CipherColor.textPrimary)
            Text(String(localized: "demo.selftest.account", defaultValue: "Signing in as @\(command.username)"))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
            if let runner {
                DemoBotSelfTestStepLabel(step: runner.step)
                    .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: runner.step)
            }
        }
        .padding(CipherSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CipherColor.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "demo.selftest.a11y", defaultValue: "Echo self-test in progress"))
        .task {
            guard runner == nil else { return }
            let runner = DemoBotSelfTestRunner(container: container, command: command)
            self.runner = runner
            let outcome = await runner.run()
            if exitsWhenFinished {
                DemoBotSelfTest.report(outcome)
            }
        }
    }
}

/// The current step as one line, plus the verdict in mono once there is one.
struct DemoBotSelfTestStepLabel: View {
    let step: DemoBotSelfTestRunner.Step

    var body: some View {
        VStack(spacing: CipherSpacing.sm) {
            if case .finished(let outcome) = step {
                Text(outcome.line)
                    .font(CipherTypography.monoSmall)
                    .foregroundStyle(outcome.isPass ? CipherColor.success : CipherColor.danger)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .tint(CipherColor.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
            }
        }
        .accessibilityLabel(title)
    }

    private var title: String {
        switch step {
        case .idle: String(localized: "demo.selftest.step.idle", defaultValue: "Starting")
        case .signingIn: String(localized: "demo.selftest.step.signingIn", defaultValue: "Signing in")
        case .publishingKeys: String(localized: "demo.selftest.step.publishingKeys", defaultValue: "Publishing identity keys")
        case .buildingStack: String(localized: "demo.selftest.step.buildingStack", defaultValue: "Opening the local store")
        case .startingEcho: String(localized: "demo.selftest.step.startingEcho", defaultValue: "Starting Echo")
        case .connecting: String(localized: "demo.selftest.step.connecting", defaultValue: "Connecting to the relay")
        case .startingConversation: String(localized: "demo.selftest.step.startingConversation", defaultValue: "Opening a chat with Echo")
        case .awaitingReply: String(localized: "demo.selftest.step.awaitingReply", defaultValue: "Sent “ping”, waiting for Echo")
        case .finished(let outcome): Self.verdict(outcome)
        }
    }

    private static func verdict(_ outcome: DemoBotSelfTest.Outcome) -> String {
        if outcome.isPass {
            return String(localized: "demo.selftest.step.passed", defaultValue: "Passed")
        }
        return String(localized: "demo.selftest.step.failed", defaultValue: "Failed")
    }
}

#Preview("Running") {
    DemoBotSelfTestStepLabel(step: .awaitingReply)
        .padding()
        .background(CipherColor.background)
}

#Preview("Finished") {
    DemoBotSelfTestStepLabel(step: .finished(.pass(replyLength: 42, elapsedMillis: 1_280)))
        .padding()
        .background(CipherColor.background)
}

#Preview("Screen") {
    DemoBotSelfTestView(
        command: DemoBotSelfTest.Command(target: "echo", username: "alice", password: "cipher-alice"),
        exitsWhenFinished: false
    )
    .environment(AppContainer.mock())
}
#endif
