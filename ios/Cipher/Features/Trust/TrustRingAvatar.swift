import CipherDesign
import SwiftUI

/// An initials avatar wrapped in the trust ring, as one tappable control. Used in the chat header and
/// anywhere a contact appears with a trust verdict; the tap opens the "Why this chat is secure" sheet.
struct TrustRingAvatar: View {
    let name: String
    let seed: String
    let score: Double
    var segments = TrustRingViewModel.segments
    var size: CGFloat = 38
    /// Draws a presence dot when known; nil hides it (inbox rows show presence elsewhere).
    var isOnline: Bool?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TrustRing(score: score, segments: segments, size: size) {
                InitialsAvatar(name: name, seed: seed, size: size * 0.78) {
                    if let isOnline {
                        PresenceDot(online: isOnline, size: max(7, size * 0.24))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "trust.ring.a11y", defaultValue: "\(name), trust \(percent) percent"))
        .accessibilityHint(String(localized: "trust.ring.a11y.hint", defaultValue: "Opens why this chat is secure"))
    }

    private var percent: Int {
        Int((min(max(score, 0), 1) * 100).rounded())
    }
}

#Preview {
    HStack(spacing: CipherSpacing.xl) {
        TrustRingAvatar(name: "Mara Kovač", seed: "mara", score: 0.15, isOnline: false) {}
        TrustRingAvatar(name: "Devraj Iyer", seed: "devraj", score: 0.5, size: 56, isOnline: true) {}
        TrustRingAvatar(name: "Sofía Lindqvist", seed: "sofia", score: 1, size: 72) {}
    }
    .padding(CipherSpacing.xxl)
    .background(CipherColor.background)
}
