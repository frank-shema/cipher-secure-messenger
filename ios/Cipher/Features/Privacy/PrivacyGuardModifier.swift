import CipherDesign
import SwiftUI

extension View {
    /// Shoulder-surf protection for a whole screen tree. Blurs and curtains the content while the phone
    /// is face down, and draws the branded `PrivacyCurtain` whenever the scene is not active so the app
    /// switcher snapshot, Control Centre pulls and incoming-call banners never capture a message.
    ///
    /// Apply once, as high as possible (the root view), so nothing can render outside it.
    func privacyGuard(_ monitor: FlipToHideMonitor) -> some View {
        modifier(PrivacyGuardModifier(monitor: monitor))
    }
}

struct PrivacyGuardModifier: ViewModifier {
    let monitor: FlipToHideMonitor

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSceneActive: Bool {
        scenePhase == .active
    }

    func body(content: Content) -> some View {
        content
            .flipToHide(isHidden: monitor.isHidden && isSceneActive)
            .overlay {
                if !isSceneActive {
                    PrivacyCurtain(subtitle: String(localized: "privacy.curtain.subtitle", defaultValue: "Security you can see and feel"))
                        .transition(.opacity)
                }
            }
            .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isSceneActive)
            .onChange(of: scenePhase, initial: true) { _, phase in
                monitor.handleScenePhase(phase)
                PrivacyLog.curtain.debug("scene phase \(String(describing: phase), privacy: .public)")
            }
            .onDisappear { monitor.stop() }
    }
}

#Preview("Flip to hide") {
    struct Demo: View {
        @State private var source = PreviewGravitySource()
        @State private var monitor: FlipToHideMonitor?
        @State private var faceDown = false

        var body: some View {
            Group {
                if let monitor {
                    VStack(alignment: .leading, spacing: CipherSpacing.md) {
                        ForEach(0..<5, id: \.self) { index in
                            Text(verbatim: "Message \(index + 1): the keys are under the mat.")
                                .padding(CipherSpacing.md)
                                .foregroundStyle(CipherColor.textPrimary)
                                .background(CipherColor.bubbleIncoming, in: RoundedRectangle(cornerRadius: CipherRadius.bubble))
                        }
                        Spacer()
                        Button(faceDown ? "Turn face up" : "Turn face down") {
                            faceDown.toggle()
                            source.emit(gravityZ: faceDown ? 1 : -1)
                        }
                        .buttonStyle(.cipherGhost)
                    }
                    .padding(CipherSpacing.lg)
                    .privacyGuard(monitor)
                }
            }
            .background(CipherColor.background)
            .onAppear {
                if monitor == nil {
                    monitor = FlipToHideMonitor(source: source, defaults: UserDefaults(suiteName: "preview.privacy") ?? .standard)
                }
            }
        }
    }
    return Demo()
}
