import CipherCore
import CipherDesign
import SwiftUI

/// A Time Capsule that has not reached its unlock time. The relay cannot enforce `unlockAt` (it
/// lives inside the ciphertext), so the seal is a promise this client keeps: the plaintext is
/// decrypted but not shown until the moment passes, then revealed with the decrypt animation.
struct SealedCapsuleBubble: View {
    let message: Message
    let text: String
    let unlockAt: Date
    let now: Date
    let onUnlocked: () -> Void

    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            HStack(spacing: CipherSpacing.xs) {
                Image(systemName: "envelope.badge.clock")
                Text(String(localized: "chat.capsule.title", defaultValue: "Time Capsule"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(unlockAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(CipherColor.textSecondary)

            SealedCapsuleView(unlockAt: unlockAt, onUnlocked: unlock) {
                DecryptText(text, reveal: reveal, duration: 0.9)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BubbleMetaView(message: message, now: now)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(CipherSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CipherRadius.bubble, style: .continuous)
                .fill(CipherColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.bubble, style: .continuous)
                .strokeBorder(CipherColor.accentSecondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "chat.capsule.a11y",
                                   defaultValue: "Sealed time capsule, opens \(unlockAt.formatted(date: .abbreviated, time: .shortened))"))
    }

    private func unlock() {
        reveal = true
        onUnlocked()
    }
}

#Preview {
    let now = PreviewMessaging.frozenNow
    let sealed = PreviewMessaging.sampleMessages.first { $0.flags.unlockAt != nil }
    VStack {
        if let sealed, case .text(let body) = sealed.content, let unlockAt = sealed.flags.unlockAt {
            SealedCapsuleBubble(message: sealed, text: body, unlockAt: unlockAt, now: now) {}
            SealedCapsuleBubble(message: sealed, text: body, unlockAt: Date().addingTimeInterval(4), now: now) {}
        }
    }
    .padding()
    .background(CipherColor.background)
}
