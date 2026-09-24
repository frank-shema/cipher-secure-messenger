import SwiftUI

/// Cipher's signature reveal: text renders as cipher glyphs and resolves, left to
/// right, into plaintext with a brief teal flash on each resolved character.
///
/// The effect is driven by `TimelineView(.animation)` and a deterministic
/// ``DecryptSchedule``, so it is smooth, cheap and reproducible. With Reduce Motion
/// on, the glyphs crossfade into plaintext instead.
public struct DecryptText: View {
    private let text: String
    private let reveal: Bool
    private let duration: Double
    private let onCompleted: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStart: Date?
    @State private var isFinished: Bool

    /// Creates a decrypting text view.
    /// - Parameters:
    ///   - text: The plaintext to reveal.
    ///   - reveal: `false` shows cipher glyphs; flipping to `true` plays the reveal.
    ///   - duration: Time for the reveal to sweep across the text, in seconds.
    ///   - onCompleted: Called once the last character has resolved.
    public init(_ text: String, reveal: Bool, duration: Double = 0.4, onCompleted: (() -> Void)? = nil) {
        self.text = text
        self.reveal = reveal
        self.duration = duration
        self.onCompleted = onCompleted
        _isFinished = State(initialValue: reveal)
    }

    private var characters: [Character] { Array(text) }
    private var seed: UInt64 { CipherGlyphs.seed(for: text) }
    private var schedule: DecryptSchedule { DecryptSchedule(count: characters.count, duration: duration) }

    public var body: some View {
        Group {
            if reduceMotion {
                reducedMotionBody
            } else {
                animatedBody
            }
        }
        .accessibilityLabel(reveal ? text : "Encrypted message")
        .onChange(of: reveal) { _, isRevealing in
            isFinished = false
            revealStart = isRevealing ? .now : nil
        }
        .task(id: revealStart) {
            guard revealStart != nil else { return }
            let wait = reduceMotion ? CipherMotion.Duration.fast : schedule.totalDuration
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            isFinished = true
            onCompleted?()
        }
    }

    private var reducedMotionBody: some View {
        Text(reveal ? text : CipherGlyphs.scramble(text, seed: seed))
            .fontDesign(reveal ? .default : .monospaced)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: CipherMotion.Duration.fast), value: reveal)
    }

    private var animatedBody: some View {
        let isAnimating = revealStart != nil && !isFinished
        return TimelineView(.animation(minimumInterval: 1 / 60, paused: !isAnimating)) { context in
            composed(at: context.date)
        }
    }

    private func composed(at date: Date) -> Text {
        if isFinished { return Text(text) }
        let elapsed = revealStart.map { date.timeIntervalSince($0) } ?? 0
        let frame = Int(elapsed * 45)
        return characters.enumerated().reduce(Text(verbatim: "")) { partial, item in
            partial + piece(for: item.element, at: item.offset, elapsed: elapsed, frame: frame)
        }
    }

    private func piece(for character: Character, at index: Int, elapsed: Double, frame: Int) -> Text {
        guard !character.isWhitespace else { return Text(String(character)) }
        let state = revealStart == nil ? .cipher : schedule.state(of: index, at: elapsed)
        switch state {
        case .cipher:
            return Text(String(CipherGlyphs.glyph(index: index, frame: frame / 12, seed: seed)))
                .foregroundStyle(CipherColor.textSecondary)
                .fontDesign(.monospaced)
        case .resolving:
            return Text(String(CipherGlyphs.glyph(index: index, frame: frame, seed: seed)))
                .foregroundStyle(CipherColor.accent.opacity(0.85))
                .fontDesign(.monospaced)
        case .flashing:
            return Text(String(character)).foregroundStyle(CipherColor.accent).bold()
        case .plain:
            return Text(String(character))
        }
    }
}

#Preview("DecryptText") {
    struct Demo: View {
        @State private var reveal = false
        var body: some View {
            VStack(alignment: .leading, spacing: CipherSpacing.lg) {
                DecryptText("Meet me at the old lighthouse at nine.", reveal: reveal, duration: 0.6)
                    .font(.title3.weight(.medium))
                DecryptText("Security you can see and feel.", reveal: reveal)
                    .font(.body)
                    .foregroundStyle(CipherColor.textSecondary)
                Button(reveal ? "Encrypt" : "Decrypt") { reveal.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(CipherColor.accent)
            }
            .padding(CipherSpacing.xl)
            .foregroundStyle(CipherColor.textPrimary)
            .background(CipherColor.background)
        }
    }
    return Demo()
}
