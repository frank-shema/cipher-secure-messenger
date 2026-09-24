import CipherDesign
import SwiftUI

struct RootView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var emblemSize: CGFloat = 72

    var body: some View {
        ZStack {
            CipherColor.background
                .ignoresSafeArea()

            VStack(spacing: CipherSpacing.xl) {
                Image(systemName: "lock.shield")
                    .font(.system(size: emblemSize, weight: .semibold))
                    .foregroundStyle(CipherColor.accent)
                    .accessibilityHidden(true)

                VStack(spacing: CipherSpacing.sm) {
                    Text(String(localized: "root.title", defaultValue: "Cipher"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(CipherColor.textPrimary)

                    Text(String(localized: "root.subtitle", defaultValue: "Security you can see and feel"))
                        .font(.body)
                        .foregroundStyle(CipherColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, CipherSpacing.xxl)
        }
    }
}

#Preview {
    RootView()
}
