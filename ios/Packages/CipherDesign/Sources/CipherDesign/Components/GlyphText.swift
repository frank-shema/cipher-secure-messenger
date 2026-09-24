import SwiftUI

/// Renders `text` as a stable run of cipher glyphs of the same length,
/// preserving word breaks so the silhouette of the message survives.
public struct GlyphText: View {
    private let text: String
    private let font: Font

    /// Creates a glyph rendering of `text`.
    /// - Parameters:
    ///   - text: Plaintext whose shape is mirrored; content is never shown.
    ///   - font: Monospaced font; defaults to `CipherTypography.mono`.
    public init(_ text: String, font: Font = CipherTypography.mono) {
        self.text = text
        self.font = font
    }

    public var body: some View {
        Text(GlyphText.render(text))
            .font(font)
            .foregroundStyle(CipherColor.glyph)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text("Encrypted message"))
    }

    /// Deterministic glyph rendering used by `body`; exposed for tests.
    public static func render(_ text: String) -> String {
        var rendered = String()
        rendered.reserveCapacity(text.count)
        var wordIndex = 0
        var wordLength = 0
        for character in text {
            if character.isWhitespace || character.isNewline {
                flush(&rendered, wordIndex: wordIndex, length: wordLength)
                rendered.append(character)
                wordIndex += 1
                wordLength = 0
            } else {
                wordLength += 1
            }
        }
        flush(&rendered, wordIndex: wordIndex, length: wordLength)
        return rendered
    }

    private static func flush(_ out: inout String, wordIndex: Int, length: Int) {
        guard length > 0 else { return }
        out.append(GlyphAlphabet.string(seeded: "\(wordIndex):\(length):\(out.count)", length: length))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.md) {
        GlyphText("Meet me at the old lighthouse at nine.")
        GlyphText("Keys rotated.", font: CipherTypography.monoSmall)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
