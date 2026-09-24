import CipherDesign
import SwiftUI

/// Icon, title, detail and a chevron; the shared row shape for tappable settings.
struct SettingsRow: View {
    let icon: String
    let title: String
    let detail: String
    var showsChevron = true

    var body: some View {
        HStack(spacing: CipherSpacing.md) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(CipherColor.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CipherTypography.body).foregroundStyle(CipherColor.textPrimary)
                Text(detail).font(CipherTypography.caption).foregroundStyle(CipherColor.textSecondary)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CipherColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        SettingsRow(icon: "faceid", title: "App lock", detail: "PIN and Face ID")
        SettingsRow(icon: "waveform.path.ecg", title: "Demo companion (Echo)", detail: "A local bot that replies", showsChevron: false)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
