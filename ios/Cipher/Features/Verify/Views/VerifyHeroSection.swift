import CipherCore
import CipherDesign
import SwiftUI

/// Who is being verified, the eight emoji and the one instruction that matters: read them aloud.
struct VerifyHeroSection: View {
    let contact: Contact
    let fingerprint: SafetyFingerprint?
    let phase: VerifyPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: CipherSpacing.xl) {
            identity
            fingerprintGrid
            guidance
        }
    }

    private var identity: some View {
        VStack(spacing: CipherSpacing.sm) {
            InitialsAvatar(name: contact.user.displayName, seed: contact.user.id.description, size: 64) {
                ShieldBadge(state: contact.trust.shieldState, size: 18)
                    .padding(3)
                    .background(CipherColor.background, in: .circle)
            }
            Text(contact.user.displayName)
                .font(CipherTypography.headline)
                .foregroundStyle(CipherColor.textPrimary)
            Text(verbatim: "@\(contact.user.username)")
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var fingerprintGrid: some View {
        switch phase {
        case .ready:
            if let fingerprint {
                EmojiFingerprintView(emoji: fingerprint.emoji)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        case .loading:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CipherSpacing.md), count: 4), spacing: CipherSpacing.md) {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonView(cornerRadius: CipherRadius.md).frame(height: 64)
                }
            }
            .accessibilityLabel(String(localized: "verify.fingerprint.loading", defaultValue: "Computing fingerprint"))
        case .unavailable(let reason):
            HStack(spacing: CipherSpacing.md) {
                ShieldBadge(state: .warning, size: 22)
                Text(reason)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CipherSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CipherColor.surface, in: .rect(cornerRadius: CipherRadius.lg))
        }
    }

    private var guidance: some View {
        SectionCard {
            HStack(alignment: .top, spacing: CipherSpacing.md) {
                Image(systemName: "phone.and.waveform.fill")
                    .font(.title2)
                    .foregroundStyle(CipherColor.accent)
                    .symbolEffect(.variableColor.iterative, options: reduceMotion ? .nonRepeating : .repeating, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                    Text(String(localized: "verify.guidance.title", defaultValue: "Read these aloud on a call"))
                        .font(CipherTypography.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                    Text(String(
                        localized: "verify.guidance.body",
                        defaultValue: """
                            \(contact.user.displayName) sees the same eight emoji on their screen. \
                            If even one differs, someone may be sitting between you: stop and compare in person.
                            """
                    ))
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VerifyHeroSection(
            contact: MessagingFixtures.bobContact(now: PreviewMessaging.frozenNow),
            fingerprint: VerifyPreviews.sampleFingerprint,
            phase: .ready
        )
        .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
}
