import CipherDesign
import SwiftUI

/// Inline error surface for a relay problem (RFC 7807) or any other failure: title, one sentence of
/// detail and, when the relay supplied one, the correlation id support can search for.
struct ProblemBanner: View {
    let problem: PresentableProblem
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(CipherColor.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(problem.title)
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(problem.detail)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let correlationId = problem.correlationId {
                    Text(String(localized: "problem.correlation", defaultValue: "Reference") + " " + correlationId)
                        .font(CipherTypography.monoSmall)
                        .foregroundStyle(CipherColor.textSecondary)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CipherColor.textSecondary)
                        .padding(CipherSpacing.xs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "problem.dismiss", defaultValue: "Dismiss error"))
            }
        }
        .padding(CipherSpacing.lg)
        .background(CipherColor.danger.opacity(0.10), in: .rect(cornerRadius: CipherRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: CipherRadius.md)
                .strokeBorder(CipherColor.danger.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        ProblemBanner(
            problem: PresentableProblem(
                title: "Username taken",
                detail: "Someone already registered this username.",
                correlationId: "8e1f2a3b-preview"
            ),
            onDismiss: {}
        )
        ProblemBanner(problem: PresentableProblem(title: "Offline", detail: "Check your connection and try again."))
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
