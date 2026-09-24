import SwiftUI

/// A circular progress ring overlaid on media while it uploads or downloads.
public struct AttachmentProgressRing: View {
    private let progress: Double
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a ring.
    /// - Parameters:
    ///   - progress: `0...1`; values outside are clamped.
    ///   - size: Ring diameter.
    public init(progress: Double, size: CGFloat = 44) {
        self.progress = min(max(progress, 0), 1)
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(CipherColor.overlay)
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CipherGradient.primaryAction, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: progress)
            Image(systemName: progress >= 1 ? "checkmark" : "arrow.up")
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("Attachment progress"))
        .accessibilityValue(Text(progress.formatted(.percent.precision(.fractionLength(0)))))
    }
}

#Preview {
    HStack(spacing: CipherSpacing.lg) {
        AttachmentProgressRing(progress: 0.15)
        AttachmentProgressRing(progress: 0.6)
        AttachmentProgressRing(progress: 1)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
