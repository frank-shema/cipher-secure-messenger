import CipherDesign
import SwiftUI

/// Explains, in plain words, what a duress PIN does before offering to set one. Hidden until the real
/// PIN exists because it is meaningless on its own.
struct DuressPINSection: View {
    let lock: AppLockManager
    let onCreate: () -> Void
    let onChange: () -> Void
    let onRemove: () -> Void

    var body: some View {
        SectionCard(title: String(localized: "lock.section.duress", defaultValue: "Duress PIN")) {
            VStack(alignment: .leading, spacing: CipherSpacing.md) {
                HStack(spacing: CipherSpacing.md) {
                    Image(systemName: "theatermasks.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CipherColor.accentSecondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "lock.duress.status.title", defaultValue: "Duress PIN"))
                            .font(CipherTypography.body)
                            .foregroundStyle(CipherColor.textPrimary)
                        Text(statusDetail)
                            .font(CipherTypography.caption)
                            .foregroundStyle(lock.hasDuressPIN ? CipherColor.success : CipherColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
                Text(explanation)
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !lock.isConfigured {
                    Text(String(localized: "lock.duress.needsPIN", defaultValue: "Turn on App lock and set a PIN first."))
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.warning)
                } else if lock.hasDuressPIN {
                    HStack(spacing: CipherSpacing.sm) {
                        CipherButton(String(localized: "lock.duress.change", defaultValue: "Change"),
                                     systemImage: "key.fill", variant: .ghost, action: onChange)
                        CipherButton(String(localized: "lock.duress.remove", defaultValue: "Remove"),
                                     systemImage: "trash", variant: .destructive, action: onRemove)
                    }
                } else {
                    CipherButton(String(localized: "lock.duress.set", defaultValue: "Set a duress PIN"),
                                 systemImage: "theatermasks", action: onCreate)
                }
            }
        }
    }

    private var statusDetail: String {
        lock.hasDuressPIN
            ? String(localized: "lock.duress.status.on", defaultValue: "On. Opens a decoy inbox.")
            : String(localized: "lock.duress.status.off", defaultValue: "Not set")
    }

    private var explanation: String {
        String(
            localized: "lock.duress.explanation",
            defaultValue: "A duress PIN is a second PIN. If someone forces you to unlock Cipher, enter it instead of your "
                + "real PIN: the app opens normally but shows a harmless, made-up inbox. Your real conversations stay "
                + "hidden and untouched, and nothing on screen reveals that another inbox exists. Only your real PIN "
                + "brings your own messages back."
        )
    }
}

#Preview("Set") {
    DuressPINSection(lock: .preview(locked: false), onCreate: {}, onChange: {}, onRemove: {})
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}

#Preview("Not set") {
    DuressPINSection(lock: .preview(locked: false, duressPIN: nil), onCreate: {}, onChange: {}, onRemove: {})
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
