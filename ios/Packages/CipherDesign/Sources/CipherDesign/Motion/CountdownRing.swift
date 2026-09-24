import SwiftUI

/// A thin ring that empties as a disappearing message runs out of time, with an
/// optional compact remaining-time label in the centre.
public struct CountdownRing: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let remaining: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a countdown ring.
    /// - Parameters:
    ///   - progress: Fraction of time left, `0...1`; out-of-range values are clamped.
    ///   - lineWidth: Stroke width of the ring.
    ///   - tint: Colour of the remaining arc.
    ///   - remaining: Seconds left; when provided, a compact label such as "45s" is shown.
    public init(progress: Double, lineWidth: CGFloat = 3, tint: Color = CipherColor.accent, remaining: TimeInterval? = nil) {
        self.progress = Self.clamp(progress)
        self.lineWidth = lineWidth
        self.tint = tint
        self.remaining = remaining
    }

    /// Clamps a progress value into `0...1`, treating NaN as empty.
    public static func clamp(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }

    /// A compact label for a remaining duration: "12s", "4m", "2h" or "3d".
    public static func label(forRemaining seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        switch whole {
        case ..<60: return "\(whole)s"
        case ..<3600: return "\(whole / 60)m"
        case ..<86400: return "\(whole / 3600)h"
        default: return "\(whole / 86400)d"
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1).reduced(reduceMotion), value: progress)
            if let remaining {
                Text(Self.label(forRemaining: remaining))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(lineWidth + 2)
                    .foregroundStyle(tint)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let remaining {
            return "Disappears in \(Self.label(forRemaining: remaining))"
        }
        return "\(Int(progress * 100)) percent of time remaining"
    }
}

#Preview("CountdownRing") {
    HStack(spacing: CipherSpacing.xl) {
        CountdownRing(progress: 0.9).frame(width: 20)
        CountdownRing(progress: 0.5, lineWidth: 4, remaining: 42).frame(width: 44)
        CountdownRing(progress: 0.15, lineWidth: 4, tint: CipherColor.warning, remaining: 5).frame(width: 44)
        CountdownRing(progress: 1.4, lineWidth: 5, tint: CipherColor.accentSecondary, remaining: 7200).frame(width: 56)
    }
    .padding(CipherSpacing.xxl)
    .background(CipherColor.background)
}
