import SwiftUI

/// How much a contact's identity has been verified, bucketed for colour.
public enum TrustTier: Sendable, Equatable {
    /// Unverified or recently changed keys.
    case low
    /// Partially verified (for example, keys unchanged for a long time).
    case medium
    /// Verified in person or via safety-number comparison.
    case high
}

/// A segmented ring around a slot (usually an avatar) that fills and shifts colour
/// from danger through warning to accent as `score` grows. Score changes animate.
public struct TrustRing<Content: View>: View {
    private let score: Double
    private let segments: Int
    private let size: CGFloat
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a trust ring around `content`.
    /// - Parameters:
    ///   - score: Trust from `0` (none) to `1` (fully verified); clamped.
    ///   - segments: Number of arc segments; at least 1.
    ///   - size: Outer diameter of the ring.
    ///   - content: The view shown inside the ring.
    public init(score: Double, segments: Int = 8, size: CGFloat = 56, @ViewBuilder content: () -> Content) {
        self.score = min(max(score.isNaN ? 0 : score, 0), 1)
        self.segments = max(segments, 1)
        self.size = size
        self.content = content()
    }

    /// The tier a score falls into: below 0.4 is low, below 0.75 is medium, otherwise high.
    public static func tier(for score: Double) -> TrustTier {
        switch score {
        case ..<0.4: return .low
        case ..<0.75: return .medium
        default: return .high
        }
    }

    /// The ring colour for a score, mapped via ``tier(for:)``.
    public static func color(for score: Double) -> Color {
        switch tier(for: score) {
        case .low: return CipherColor.danger
        case .medium: return CipherColor.warning
        case .high: return CipherColor.accent
        }
    }

    private var lineWidth: CGFloat { max(2, size * 0.055) }

    public var body: some View {
        ZStack {
            TrustRingShape(progress: 1, segments: segments)
                .stroke(CipherColor.textSecondary.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            TrustRingShape(progress: score, segments: segments)
                .stroke(Self.color(for: score), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: Self.color(for: score).opacity(0.5), radius: 4)
            content
                .clipShape(Circle())
                .padding(lineWidth * 2.2)
        }
        .frame(width: size, height: size)
        .animation(CipherMotion.gentle.reduced(reduceMotion), value: score)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Trust \(Int(score * 100)) percent")
    }
}

/// Segmented arcs; `progress` fills segments clockwise from the top, partially filling the last.
struct TrustRingShape: Shape {
    var progress: Double
    let segments: Int

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let span = 360.0 / Double(segments)
        let gap = segments > 1 ? min(span * 0.22, 10) : 0
        for index in 0..<segments {
            let fill = min(max(progress * Double(segments) - Double(index), 0), 1)
            guard fill > 0 else { continue }
            let start = Angle.degrees(-90 + Double(index) * span + gap / 2)
            let end = Angle.degrees(start.degrees + (span - gap) * fill)
            path.move(to: CGPoint(
                x: center.x + radius * CGFloat(cos(start.radians)),
                y: center.y + radius * CGFloat(sin(start.radians))
            ))
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        }
        return path
    }
}

#Preview("TrustRing") {
    HStack(spacing: CipherSpacing.xl) {
        ForEach([0.2, 0.55, 0.9], id: \.self) { score in
            TrustRing(score: score, segments: 8, size: 64) {
                Circle().fill(CipherColor.accentSecondary.gradient)
                    .overlay(Text(verbatim: "AK").font(.headline).foregroundStyle(.white))
            }
        }
    }
    .padding(CipherSpacing.xxl)
    .background(CipherColor.background)
}
