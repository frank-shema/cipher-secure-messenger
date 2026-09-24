import SwiftUI

/// The triangular flap of a sealed envelope, hinged along the top edge.
struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A violet wax seal stamped with a cipher glyph; `isCracked` breaks it apart.
struct WaxSealView: View {
    let isCracked: Bool
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(CipherColor.accentSecondary.gradient)
                .shadow(color: CipherColor.accentSecondary.opacity(0.45), radius: 8, y: 3)
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                .padding(4)
            Text(verbatim: "◈")
                .font(.system(size: size * 0.42, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(isCracked ? 1.5 : 1)
        .rotationEffect(.degrees(isCracked ? 24 : 0))
        .opacity(isCracked ? 0 : 1)
        .accessibilityHidden(true)
    }
}

/// The paper body of the envelope with a faint inner fold.
struct EnvelopeBodyView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous)
            .fill(CipherColor.surfaceElevated)
            .overlay {
                RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous)
                    .strokeBorder(CipherColor.accent.opacity(0.25), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                EnvelopeFlapShape()
                    .rotation(.degrees(180))
                    .fill(CipherColor.textSecondary.opacity(0.08))
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
            }
    }
}

/// Formats a remaining interval as `mm:ss` or `h:mm:ss`.
enum SealedCountdownFormatter {
    static func string(for remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("Envelope parts") {
    VStack(spacing: CipherSpacing.xl) {
        EnvelopeBodyView().frame(width: 220, height: 130)
        HStack(spacing: CipherSpacing.xl) {
            WaxSealView(isCracked: false)
            Text(SealedCountdownFormatter.string(for: 3725))
                .font(.title3.monospacedDigit())
                .foregroundStyle(CipherColor.textPrimary)
        }
    }
    .padding(CipherSpacing.xxl)
    .background(CipherColor.background)
}
