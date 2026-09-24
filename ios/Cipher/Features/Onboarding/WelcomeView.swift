import CipherDesign
import SwiftUI

/// First screen: the lock emblem, the name decrypting out of cipher glyphs, and one clear next step.
struct WelcomeView: View {
    let onContinue: (AuthViewModel.Mode) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: CipherSpacing.xl)
            AnimatedLockEmblem()
                .padding(.bottom, CipherSpacing.xxl)
            hero
            Spacer(minLength: CipherSpacing.xl)
            actions
        }
        .padding(.horizontal, CipherSpacing.xl)
        .padding(.bottom, CipherSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CipherColor.background.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 350))
            revealed = true
        }
    }

    private var hero: some View {
        VStack(spacing: CipherSpacing.md) {
            DecryptText(String(localized: "welcome.title", defaultValue: "Cipher"), reveal: revealed, duration: 0.9)
                .font(CipherTypography.title)
                .foregroundStyle(CipherColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            GlyphText(String(localized: "welcome.cipherStrip", defaultValue: "end to end encrypted"), font: CipherTypography.monoSmall)
                .opacity(0.8)
            Text(String(localized: "welcome.tagline", defaultValue: "Security you can see and feel"))
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, CipherSpacing.xs)
        }
        .opacity(revealed ? 1 : 0.6)
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: revealed)
    }

    private var actions: some View {
        VStack(spacing: CipherSpacing.md) {
            CipherButton(String(localized: "welcome.cta.register", defaultValue: "Get started"), systemImage: "arrow.right") {
                onContinue(.register)
            }
            CipherButton(String(localized: "welcome.cta.login", defaultValue: "I already have an account"), variant: .ghost) {
                onContinue(.login)
            }
            Text(String(localized: "welcome.footnote", defaultValue: "Keys are created on this device and never leave it."))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, CipherSpacing.xs)
        }
    }
}

#Preview {
    WelcomeView { _ in }
        .previewEnvironment(AppContainer.mock())
}
