import SwiftUI

/// Overlays the current toast from the `ToastCenter` in the environment.
struct ToastHostModifier: ViewModifier {
    @Environment(ToastCenter.self) private var center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                ToastView(toast: toast)
                    .padding(.top, CipherSpacing.md)
                    .padding(.horizontal, CipherSpacing.lg)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .onTapGesture { center.dismissCurrent() }
                    .accessibilityHint(Text("Tap to dismiss"))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.25), value: center.current)
    }
}

public extension View {
    /// Presents toasts from the `ToastCenter` found in the environment.
    /// Apply once near the root, after `.environment(toastCenter)`.
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}

#Preview {
    @Previewable @State var center = ToastCenter()
    VStack {
        CipherButton("Show toast") {
            center.show("Keys verified", style: .success)
            center.show("Backup complete")
        }
    }
    .padding(CipherSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CipherColor.background)
    .environment(center)
    .toastHost()
}
