import CipherDesign
import SwiftUI

/// Visual state of one bootstrap step.
enum KeyStepState: Hashable {
    case pending, active, done, blocked
}

/// One line of the three-step key story: a status disc, the step title and what it means for the person.
struct KeyBootstrapStepRow: View {
    let step: KeyBootstrapStep
    let state: KeyStepState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            statusDisc
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(title)
                    .font(CipherTypography.headline)
                    .foregroundStyle(state == .pending ? CipherColor.textSecondary : CipherColor.textPrimary)
                Text(subtitle)
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .opacity(state == .pending ? 0.6 : 1)
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState)
    }

    private var statusDisc: some View {
        ZStack {
            Circle()
                .fill(state == .done ? AnyShapeStyle(CipherGradient.primaryAction) : AnyShapeStyle(CipherColor.surfaceElevated))
                .overlay(Circle().strokeBorder(state == .active ? CipherColor.accent : CipherColor.divider, lineWidth: 1.5))
            switch state {
            case .pending:
                Text("\(step.rawValue + 1)")
                    .font(CipherTypography.monoSmall)
                    .foregroundStyle(CipherColor.textSecondary)
            case .active:
                ProgressView().tint(CipherColor.accent).controlSize(.small)
            case .done:
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: 0x0B0F1A))
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            case .blocked:
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CipherColor.warning)
            }
        }
        .frame(width: 32, height: 32)
    }

    private var title: String {
        switch step {
        case .generating: String(localized: "keygen.step.generating.title", defaultValue: "Generating Curve25519 keys")
        case .sealing: String(localized: "keygen.step.sealing.title", defaultValue: "Sealing them in the Keychain")
        case .publishing: String(localized: "keygen.step.publishing.title", defaultValue: "Publishing only the public half")
        }
    }

    private var subtitle: String {
        switch step {
        case .generating:
            String(localized: "keygen.step.generating.subtitle", defaultValue: "X25519 for agreement, Ed25519 for signatures.")
        case .sealing:
            String(localized: "keygen.step.sealing.subtitle", defaultValue: "Private halves stay on this device, protected by it.")
        case .publishing:
            String(localized: "keygen.step.publishing.subtitle", defaultValue: "The relay only ever sees public keys.")
        }
    }

    private var accessibilityState: String {
        switch state {
        case .pending: String(localized: "keygen.step.state.pending", defaultValue: "Pending")
        case .active: String(localized: "keygen.step.state.active", defaultValue: "In progress")
        case .done: String(localized: "keygen.step.state.done", defaultValue: "Done")
        case .blocked: String(localized: "keygen.step.state.blocked", defaultValue: "Needs attention")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.lg) {
        KeyBootstrapStepRow(step: .generating, state: .done)
        KeyBootstrapStepRow(step: .sealing, state: .active)
        KeyBootstrapStepRow(step: .publishing, state: .pending)
        KeyBootstrapStepRow(step: .publishing, state: .blocked)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
