import CipherCore
import CipherDesign
import SwiftUI

/// Drag a bubble to the right to reply. The gesture only claims clearly horizontal drags so the
/// list keeps scrolling normally, and it fires once per swipe at the threshold with a haptic.
struct SwipeToReply: ViewModifier {
    let onReply: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var didTrigger = false

    private let threshold: CGFloat = 64
    private let maxTravel: CGFloat = 88

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CipherColor.accent)
                    .opacity(min(offset / threshold, 1))
                    .scaleEffect(didTrigger ? 1.15 : 0.9)
                    .offset(x: max(offset - 40, -8))
                    .accessibilityHidden(true)
            }
            .simultaneousGesture(dragGesture)
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: offset)
            .accessibilityAction(named: String(localized: "chat.menu.reply", defaultValue: "Reply"), onReply)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 0, horizontal > vertical * 1.5 else { return }
                offset = min(horizontal * 0.6, maxTravel)
                if offset >= threshold, !didTrigger {
                    didTrigger = true
                    onReply()
                }
            }
            .onEnded { _ in
                offset = 0
                didTrigger = false
            }
    }
}

extension View {
    func swipeToReply(_ onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReply(onReply: onReply))
    }
}

#Preview {
    Text("Swipe me right")
        .padding()
        .bubbleChrome(direction: .incoming, tail: .leading)
        .swipeToReply {}
        .padding()
        .background(CipherColor.background)
}
