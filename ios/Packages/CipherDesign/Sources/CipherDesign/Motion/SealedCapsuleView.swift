import SwiftUI

/// A time-locked message: a sealed envelope with a wax seal and live countdown
/// that cracks open at `unlockAt`, revealing its content and calling `onUnlocked`.
///
/// With Reduce Motion on, the seal and flap fade instead of animating.
public struct SealedCapsuleView<Content: View>: View {
    private let unlockAt: Date
    private let now: Date?
    private let onUnlocked: (() -> Void)?
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    /// Creates a sealed capsule with custom content revealed on unlock.
    /// - Parameters:
    ///   - unlockAt: The moment the seal opens.
    ///   - now: A fixed clock for previews and tests; `nil` uses the live clock.
    ///   - onUnlocked: Called once, when the opening animation starts.
    ///   - content: The message revealed inside the envelope.
    public init(unlockAt: Date, now: Date? = nil, onUnlocked: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.unlockAt = unlockAt
        self.now = now
        self.onUnlocked = onUnlocked
        self.content = content()
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = unlockAt.timeIntervalSince(now ?? context.date)
            VStack(spacing: CipherSpacing.md) {
                envelope
                Text(isOpen ? "Unlocked" : "Unlocks in \(SealedCountdownFormatter.string(for: remaining))")
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(isOpen ? CipherColor.accent : CipherColor.textSecondary)
                    .contentTransition(.numericText(countsDown: true))
            }
            .onChange(of: remaining <= 0, initial: true) { _, isDue in
                guard isDue, !isOpen else { return }
                withAnimation(CipherMotion.bouncy.crossfadeIfReduced(reduceMotion)) { isOpen = true }
                onUnlocked?()
            }
        }
        .accessibilityElement(children: isOpen ? .contain : .combine)
        .accessibilityLabel(isOpen ? "Unlocked message" : "Sealed message")
    }

    private var envelope: some View {
        ZStack(alignment: .top) {
            EnvelopeBodyView()
            content
                .padding(CipherSpacing.lg)
                .opacity(isOpen ? 1 : 0)
                .scaleEffect(isOpen ? 1 : 0.92)
                .offset(y: isOpen ? 0 : 8)
                .accessibilityHidden(!isOpen)
            EnvelopeFlapShape()
                .fill(CipherColor.surface)
                .overlay(EnvelopeFlapShape().stroke(CipherColor.accent.opacity(0.25), lineWidth: 1))
                .frame(height: 78)
                .rotation3DEffect(
                    .degrees(isOpen && !reduceMotion ? -168 : 0),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.5
                )
                .opacity(isOpen && reduceMotion ? 0 : 1)
                .zIndex(isOpen ? 0 : 2)
            WaxSealView(isCracked: isOpen)
                .offset(y: 56)
                .zIndex(3)
        }
        .frame(maxWidth: 320)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
    }
}

public extension SealedCapsuleView where Content == EmptyView {
    /// Creates a sealed capsule that simply opens at `unlockAt` with no inner content.
    init(unlockAt: Date, now: Date? = nil, onUnlocked: (() -> Void)? = nil) {
        self.init(unlockAt: unlockAt, now: now, onUnlocked: onUnlocked) { EmptyView() }
    }
}

#Preview("SealedCapsuleView") {
    VStack(spacing: CipherSpacing.xxl) {
        SealedCapsuleView(unlockAt: .now.addingTimeInterval(4)) {
            Text("Happy birthday. The key is under the third stone.")
                .font(.callout)
                .foregroundStyle(CipherColor.textPrimary)
        }
        SealedCapsuleView(unlockAt: .now.addingTimeInterval(5400), now: .now)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
