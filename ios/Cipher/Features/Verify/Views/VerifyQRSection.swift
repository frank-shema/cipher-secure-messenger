import CipherDesign
import SwiftUI

/// This account's `cipher:verify` code for the other person to scan, and the button to scan theirs.
/// The payload is copyable so the Simulator (and anyone without a camera) can still complete a check.
struct VerifyQRSection: View {
    let payload: String
    let contactName: String
    let onScan: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    var body: some View {
        SectionCard(title: String(localized: "verify.qr.title", defaultValue: "Your code")) {
            VStack(spacing: CipherSpacing.lg) {
                if payload.isEmpty {
                    SkeletonView(cornerRadius: CipherRadius.lg)
                        .frame(width: 200, height: 200)
                        .accessibilityLabel(String(localized: "verify.qr.loading", defaultValue: "Preparing your code"))
                } else {
                    QRCodeView(payload: payload, size: 200)
                        .accessibilityHint(String(
                            localized: "verify.qr.a11y.hint",
                            defaultValue: "Let \(contactName) scan this with their phone"
                        ))
                }
                Text(String(
                    localized: "verify.qr.body",
                    defaultValue: "Let \(contactName) scan this, or scan theirs. Either direction proves both sets of keys."
                ))
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                CipherButton(
                    String(localized: "verify.qr.scan", defaultValue: "Scan their code"),
                    systemImage: "qrcode.viewfinder",
                    action: onScan
                )
                copyButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = payload
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(
                copied
                    ? String(localized: "verify.qr.copied", defaultValue: "Code copied")
                    : String(localized: "verify.qr.copy", defaultValue: "Copy code as text"),
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .font(CipherTypography.caption)
            .foregroundStyle(CipherColor.accent)
            .contentTransition(.symbolEffect(.replace))
        }
        .disabled(payload.isEmpty)
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: copied)
        .accessibilityLabel(String(localized: "verify.qr.copy.a11y", defaultValue: "Copy your verification code as text"))
    }
}

#Preview {
    VerifyQRSection(payload: VerifyPreviews.samplePayload, contactName: "Bob") {}
        .padding(CipherSpacing.lg)
        .background(CipherColor.background)
}
