import CipherDesign
import SwiftUI

/// Opened from `KeyChangeWarningBanner`: what changed, what it usually means, what it could mean, and
/// the two ways out. "Verify again" is the safe path; "Trust new keys" is allowed but asks twice,
/// because accepting substituted keys is exactly what an attacker would want.
struct KeyChangeReviewView: View {
    let info: KeyChangeInfo
    let isBusy: Bool
    let onVerifyAgain: () -> Void
    let onTrustNewKeys: () -> Void

    @State private var isConfirmingTrust = false

    var body: some View {
        VStack(spacing: CipherSpacing.xl) {
            header
            SectionCard(title: String(localized: "verify.keyChange.whatChanged", defaultValue: "What changed")) {
                VStack(alignment: .leading, spacing: CipherSpacing.md) {
                    KeyChangeFactRow(
                        label: String(localized: "verify.keyChange.pinnedVersion", defaultValue: "Keys you had pinned"),
                        value: "v\(info.previousVersion)"
                    )
                    Divider().overlay(CipherColor.divider)
                    KeyChangeFactRow(
                        label: String(localized: "verify.keyChange.currentVersion", defaultValue: "Keys the relay now serves"),
                        value: currentVersion
                    )
                    Divider().overlay(CipherColor.divider)
                    KeyChangeFactRow(
                        label: String(localized: "verify.keyChange.noticedAt", defaultValue: "Noticed"),
                        value: info.changedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            SectionCard(title: String(localized: "verify.keyChange.why", defaultValue: "Why this happens")) {
                VStack(alignment: .leading, spacing: CipherSpacing.md) {
                    KeyChangeReasonRow(
                        icon: "iphone.gen3.badge.exclamationmark", tint: CipherColor.textSecondary,
                        title: String(
                            localized: "verify.keyChange.reason.device.title",
                            defaultValue: "Usually: a new phone or a reinstall"
                        ),
                        detail: String(
                            localized: "verify.keyChange.reason.device.detail",
                            defaultValue: "Keys never leave a device, so \(info.contactName) setting up Cipher again creates new ones."
                        )
                    )
                    KeyChangeReasonRow(
                        icon: "person.badge.shield.exclamationmark", tint: CipherColor.danger,
                        title: String(localized: "verify.keyChange.reason.attack.title", defaultValue: "Rarely: someone in the middle"),
                        detail: String(
                            localized: "verify.keyChange.reason.attack.detail",
                            defaultValue: """
                                A relay that swapped the keys would look exactly like this. \
                                Only comparing codes with \(info.contactName) directly can tell the two apart.
                                """
                        )
                    )
                }
            }
            actions
        }
        .confirmationDialog(
            String(localized: "verify.keyChange.trust.confirm.title", defaultValue: "Trust the new keys without checking?"),
            isPresented: $isConfirmingTrust,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "verify.keyChange.trust.confirm.action", defaultValue: "Trust new keys"),
                role: .destructive,
                action: onTrustNewKeys
            )
        } message: {
            Text(String(
                localized: "verify.keyChange.trust.confirm.message",
                defaultValue: """
                    The warning goes away and \(info.contactName) returns to \"not verified\". \
                    Anything you send is readable by whoever holds these keys.
                    """
            ))
        }
    }

    private var header: some View {
        VStack(spacing: CipherSpacing.sm) {
            ShieldBadge(state: .warning, size: 44)
            Text(String(localized: "verify.keyChange.title", defaultValue: "\(info.contactName)'s keys changed"))
                .font(CipherTypography.title)
                .foregroundStyle(CipherColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(String(
                localized: "verify.keyChange.subtitle",
                defaultValue: "Messages are still encrypted, but to keys nobody has checked."
            ))
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        VStack(spacing: CipherSpacing.md) {
            CipherButton(
                String(localized: "verify.keyChange.verifyAgain", defaultValue: "Verify again"),
                systemImage: "checkmark.shield",
                action: onVerifyAgain
            )
            .disabled(isBusy)
            CipherButton(String(localized: "verify.keyChange.trustNewKeys", defaultValue: "Trust new keys"), variant: .ghost) {
                isConfirmingTrust = true
            }
            .disabled(isBusy)
            .accessibilityHint(String(
                localized: "verify.keyChange.trustNewKeys.hint",
                defaultValue: "Clears the warning without comparing codes"
            ))
        }
    }

    private var currentVersion: String {
        guard let version = info.currentVersion else {
            return String(localized: "verify.keyChange.unknownVersion", defaultValue: "Unknown")
        }
        if let publishedAt = info.currentKeysPublishedAt {
            return "v\(version) · \(publishedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return "v\(version)"
    }
}

#Preview {
    ScrollView {
        KeyChangeReviewView(info: VerifyPreviews.sampleKeyChange, isBusy: false, onVerifyAgain: {}, onTrustNewKeys: {})
            .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
}
