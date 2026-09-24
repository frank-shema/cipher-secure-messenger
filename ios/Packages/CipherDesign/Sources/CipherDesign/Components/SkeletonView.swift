import SwiftUI

/// A shimmering placeholder block used while content loads.
public struct SkeletonView: View {
    private let cornerRadius: CGFloat
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a skeleton with the given corner radius.
    public init(cornerRadius: CGFloat = CipherRadius.sm) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(CipherColor.surfaceElevated)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(CipherGradient.shimmer)
                            .frame(width: proxy.size.width * 0.6)
                            .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityLabel(Text("Loading"))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.md) {
        HStack(spacing: CipherSpacing.md) {
            SkeletonView(cornerRadius: 22).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                SkeletonView().frame(width: 140, height: 14)
                SkeletonView().frame(width: 220, height: 12)
            }
        }
        SkeletonView(cornerRadius: CipherRadius.bubble).frame(height: 56)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
