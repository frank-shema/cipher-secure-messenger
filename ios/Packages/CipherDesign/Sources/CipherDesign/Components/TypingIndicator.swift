import SwiftUI

/// Three dots bouncing in sequence inside an incoming bubble.
public struct TypingIndicator: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a typing indicator.
    public init() {}

    public var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(CipherColor.textSecondary)
                    .frame(width: 7, height: 7)
                    .offset(y: animating && !reduceMotion ? -4 : 0)
                    .opacity(animating || reduceMotion ? 1 : 0.5)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, CipherSpacing.lg)
        .padding(.vertical, CipherSpacing.md)
        .background(CipherColor.bubbleIncoming, in: MessageBubbleShape(tail: .leading))
        .onAppear { animating = true }
        .accessibilityLabel(Text("Typing"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    TypingIndicator()
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
