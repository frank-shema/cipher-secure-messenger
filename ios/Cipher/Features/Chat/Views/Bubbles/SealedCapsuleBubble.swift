import CipherCore
import CipherDesign
import SwiftUI

/// A Time Capsule that has not reached its unlock time. The relay cannot enforce `unlockAt` (it
/// lives inside the ciphertext), so the seal is a promise this client keeps: the plaintext is
/// decrypted but not shown until the moment passes. The `TimeCapsuleUnlockCoordinator` owns that
/// moment and the haptic; this bubble only registers itself and plays the reveal it is told to.
struct SealedCapsuleBubble: View {
    let message: Message
    let text: String
    let unlockAt: Date
    let capsules: TimeCapsuleUnlockCoordinator
    let onRevealed: () -> Void

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

            SealedCapsuleView(unlockAt: unlockAt) {
                TimeCapsuleRevealView(text: text, isUnlocked: capsules.isUnlocked(message.id), onRevealed: onRevealed)
            }

            BubbleMetaView(message: message)
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
        .onAppear { capsules.track(message) }
        .onDisappear { capsules.untrack(message.id) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "chat.capsule.a11y",
                                   defaultValue: "Sealed time capsule, opens \(unlockAt.formatted(date: .abbreviated, time: .shortened))"))
    }
}

#Preview {
    let capsules = TimeCapsuleUnlockCoordinator(haptics: NoopHapticEngine())
    let sealed = PreviewMessaging.sampleMessages.first { $0.flags.unlockAt != nil }
    VStack {
        if let sealed, case .text(let body) = sealed.content, let unlockAt = sealed.flags.unlockAt {
            SealedCapsuleBubble(message: sealed, text: body, unlockAt: unlockAt, capsules: capsules) {}
            SealedCapsuleBubble(message: sealed, text: body, unlockAt: Date().addingTimeInterval(4), capsules: capsules) {}
        }
    }
    .padding()
    .background(CipherColor.background)
}
