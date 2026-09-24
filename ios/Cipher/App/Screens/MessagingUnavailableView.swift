import CipherDesign
import SwiftUI

/// Shown where a screen needs the account's messaging runtime and there is none: either it is still
/// opening (no problem to show) or it failed to build (the problem, with a retry).
struct MessagingUnavailableView: View {
    var problem: PresentableProblem?
    var onRetry: (@Sendable () -> Void)?

    var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            if let problem {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: problem.title,
                    message: problem.detail,
                    action: onRetry.map { retry in
                        EmptyStateView.Action(
                            title: String(localized: "messaging.unavailable.retry", defaultValue: "Try again"),
                            handler: { retry() }
                        )
                    }
                )
            } else {
                VStack(spacing: CipherSpacing.md) {
                    ProgressView()
                        .tint(CipherColor.accent)
                    Text(String(localized: "messaging.unavailable.opening", defaultValue: "Opening your encrypted store…"))
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Opening") {
    MessagingUnavailableView()
}

#Preview("Failed") {
    MessagingUnavailableView(problem: PresentableProblem(error: IntegrationError.notWired(component: "PersistenceStore"))) {}
}
