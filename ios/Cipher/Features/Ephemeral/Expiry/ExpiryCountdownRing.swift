import CipherCore
import CipherDesign
import SwiftUI

/// The live countdown ring in a bubble's metadata line. Wraps `CountdownRing` in a timeline so the
/// arc and label advance on their own, at the cadence `ExpiryCountdown` recommends.
struct ExpiryCountdownRing: View {
    let countdown: ExpiryCountdown
    let now: Date?
    let tint: Color
    let size: CGFloat

    /// - Parameters:
    ///   - countdown: The window to render.
    ///   - now: A frozen clock for previews; `nil` follows the live clock.
    ///   - tint: Colour of the arc while time remains; the last seconds switch to the warning tint.
    ///   - size: Diameter in points.
    init(countdown: ExpiryCountdown, now: Date? = nil, tint: Color = CipherColor.accent, size: CGFloat = 22) {
        self.countdown = countdown
        self.now = now
        self.tint = tint
        self.size = size
    }

    /// Nil-safe constructor for rows: renders nothing when the message never expires.
    init?(message: Message, now: Date? = nil, tint: Color = CipherColor.accent, size: CGFloat = 22) {
        guard let countdown = ExpiryCountdown(message: message) else { return nil }
        self.init(countdown: countdown, now: now, tint: tint, size: size)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: countdown.refreshInterval(at: now ?? .now))) { context in
            let instant = now ?? context.date
            CountdownRing(
                progress: countdown.progress(at: instant),
                lineWidth: max(2, size / 11),
                tint: countdown.isUrgent(at: instant) ? CipherColor.warning : tint,
                remaining: countdown.remaining(at: instant)
            )
            .frame(width: size, height: size)
            .accessibilityLabel(countdown.accessibilityLabel(at: instant))
        }
    }
}

#Preview {
    let now = PreviewMessaging.frozenNow
    HStack(spacing: CipherSpacing.xl) {
        ExpiryCountdownRing(countdown: ExpiryCountdown(sentAt: now.addingTimeInterval(-30), expiresAt: now.addingTimeInterval(90)),
                            now: now)
        ExpiryCountdownRing(countdown: ExpiryCountdown(sentAt: now.addingTimeInterval(-25), expiresAt: now.addingTimeInterval(5)),
                            now: now, size: 32)
        ExpiryCountdownRing(countdown: ExpiryCountdown(sentAt: now.addingTimeInterval(-3_600), expiresAt: now.addingTimeInterval(82_800)),
                            now: now, tint: CipherColor.accentSecondary, size: 44)
        ExpiryCountdownRing(countdown: ExpiryCountdown(sentAt: now, expiresAt: now.addingTimeInterval(8)), size: 44)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
