import SwiftUI

/// A `TextRenderer` variant of the decrypt effect for iOS 18 and later.
///
/// Unresolved glyphs are drawn blurred, faded and slightly sunk; a resolved glyph
/// gets a teal glow that decays over the flash. Because `elapsed` is animatable,
/// SwiftUI interpolates the whole reveal for free.
@available(iOS 18.0, macOS 15.0, *)
public struct DecryptTextRenderer: TextRenderer, Animatable {
    /// Seconds into the reveal.
    public var elapsed: Double
    /// The deterministic timing plan shared with ``DecryptText``.
    public let schedule: DecryptSchedule

    public var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    /// Creates a renderer at a given moment of the reveal.
    public init(elapsed: Double, schedule: DecryptSchedule) {
        self.elapsed = elapsed
        self.schedule = schedule
    }

    public func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var index = 0
        for line in layout {
            for run in line {
                for slice in run {
                    defer { index += 1 }
                    var copy = context
                    switch schedule.state(of: index, at: elapsed) {
                    case .cipher:
                        copy.opacity = 0.3
                        copy.addFilter(.blur(radius: 4))
                        copy.translateBy(x: 0, y: 3)
                    case .resolving:
                        copy.opacity = 0.7
                        copy.addFilter(.blur(radius: 1.5))
                        copy.translateBy(x: 0, y: CipherGlyphs.unit(index: index, frame: Int(elapsed * 45)) * 2 - 1)
                    case .flashing(let progress):
                        copy.addFilter(.shadow(color: CipherColor.accent, radius: 8 * (1 - progress)))
                    case .plain:
                        break
                    }
                    copy.draw(slice)
                }
            }
        }
    }
}

/// Plaintext that reveals through ``DecryptTextRenderer``; use it wherever the
/// iOS 18 renderer path is preferred over the glyph-substituting ``DecryptText``.
@available(iOS 18.0, macOS 15.0, *)
public struct DecryptRenderedText: View {
    private let text: String
    private let reveal: Bool
    private let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double

    /// Creates a renderer-backed decrypting text view.
    public init(_ text: String, reveal: Bool, duration: Double = 0.4) {
        self.text = text
        self.reveal = reveal
        self.duration = duration
        _elapsed = State(initialValue: reveal ? DecryptSchedule(count: text.count, duration: duration).totalDuration : 0)
    }

    private var schedule: DecryptSchedule { DecryptSchedule(count: text.count, duration: duration) }

    public var body: some View {
        Text(text)
            .textRenderer(DecryptTextRenderer(elapsed: elapsed, schedule: schedule))
            .accessibilityLabel(reveal ? text : "Encrypted message")
            .onChange(of: reveal) { _, isRevealing in
                let animation: Animation? = reduceMotion
                    ? .easeInOut(duration: CipherMotion.Duration.fast)
                    : .linear(duration: schedule.totalDuration)
                withAnimation(isRevealing ? animation : nil) {
                    elapsed = isRevealing ? schedule.totalDuration : 0
                }
            }
    }
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("DecryptRenderedText") {
    struct Demo: View {
        @State private var reveal = false
        var body: some View {
            VStack(spacing: CipherSpacing.lg) {
                DecryptRenderedText("Rendered on the GPU path.", reveal: reveal, duration: 0.6)
                    .font(.title2.weight(.semibold))
                Button("Toggle") { reveal.toggle() }
            }
            .padding(CipherSpacing.xl)
            .foregroundStyle(CipherColor.textPrimary)
            .background(CipherColor.background)
        }
    }
    return Demo()
}
