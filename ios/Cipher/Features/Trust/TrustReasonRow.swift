import CipherCore
import CipherDesign
import SwiftUI

/// One protection: a check or cross, the plain-English reason, how much fixing it is worth, and the
/// button that fixes it. Satisfied reasons have no button; nothing to do is part of the message.
struct TrustReasonRow: View {
    let reason: TrustReason
    let contact: Contact
    let disappearingTimer: TimeInterval?
    let now: Date
    let actions: TrustActions

    var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            statusIcon
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: CipherSpacing.sm) {
                    Text(TrustCopy.title(for: reason.kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CipherColor.textPrimary)
                    Spacer(minLength: 0)
                    if !reason.isSatisfied, improvesPercent > 0 {
                        improvesBadge
                    }
                }
                Text(TrustCopy.detail(for: reason.kind, contact: contact, disappearingTimer: disappearingTimer, now: now))
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = reason.action, !reason.isSatisfied {
                    actionControl(action)
                        .padding(.top, CipherSpacing.xs)
                }
            }
        }
        .padding(.vertical, CipherSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityValue(reason.isSatisfied
                            ? String(localized: "trust.reason.a11y.satisfied", defaultValue: "In place")
                            : String(localized: "trust.reason.a11y.open", defaultValue: "Not yet"))
    }

    private var improvesPercent: Int {
        Int((reason.improvesBy * 100).rounded())
    }

    private var statusIcon: some View {
        Image(systemName: reason.isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.title3)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconTint)
            .frame(width: 24)
            .accessibilityHidden(true)
    }

    private var iconTint: Color {
        if reason.isSatisfied { return CipherColor.success }
        return reason.kind == .keyChanged ? CipherColor.danger : CipherColor.warning
    }

    private var improvesBadge: some View {
        Text(String(localized: "trust.reason.improves", defaultValue: "+\(improvesPercent)%"))
            .font(CipherTypography.monoSmall.weight(.semibold))
            .foregroundStyle(CipherColor.accent)
            .padding(.horizontal, CipherSpacing.sm)
            .padding(.vertical, 2)
            .background(CipherColor.accent.opacity(0.12), in: Capsule())
            .accessibilityLabel(String(
                localized: "trust.reason.improves.a11y",
                defaultValue: "Improves trust by \(improvesPercent) percent"
            ))
    }

    @ViewBuilder
    private func actionControl(_ action: TrustAction) -> some View {
        switch action {
        case .verifyKeys:
            Button(action: actions.onVerifyKeys) {
                Label(TrustCopy.actionTitle(for: action), systemImage: "checkmark.shield")
            }
            .modifier(TrustActionStyle(tint: CipherColor.accent))
        case .reviewKeyChange:
            Button(action: actions.onReviewKeyChange) {
                Label(TrustCopy.actionTitle(for: action), systemImage: "exclamationmark.shield")
            }
            .modifier(TrustActionStyle(tint: CipherColor.danger))
        case .enableDisappearing:
            Menu {
                ForEach(DisappearingTimer.allCases.filter(\.isEnabled)) { timer in
                    Button(timer.title) {
                        actions.onEnableDisappearing(timer.rawValue)
                    }
                }
            } label: {
                Label(TrustCopy.actionTitle(for: action), systemImage: "timer")
            }
            .modifier(TrustActionStyle(tint: CipherColor.accent))
            .accessibilityHint(String(
                localized: "trust.action.enableDisappearing.hint",
                defaultValue: "Choose how long messages stay after being read"
            ))
        }
    }
}

/// The compact capsule treatment shared by every action in the sheet.
private struct TrustActionStyle: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(tint)
    }
}

#Preview {
    let contact = MessagingFixtures.contacts(now: PreviewMessaging.frozenNow)
    let report = TrustEvaluator().evaluate(TrustSignals(contact: contact[2], disappearingTimer: nil,
                                                        metadataStrippingEnabled: true, now: PreviewMessaging.frozenNow))
    ScrollView {
        SectionCard {
            ForEach(Array(report.reasons.enumerated()), id: \.element.id) { index, reason in
                if index > 0 { Divider().overlay(CipherColor.divider) }
                TrustReasonRow(reason: reason, contact: contact[2], disappearingTimer: nil,
                               now: PreviewMessaging.frozenNow, actions: TrustActions())
            }
        }
        .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
}
