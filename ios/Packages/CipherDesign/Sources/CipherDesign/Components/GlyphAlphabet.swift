import Foundation

/// The cipher glyph alphabet: 64 visually distinct characters drawn from
/// Braille patterns, box drawing, katakana and mathematical operators.
/// Used to render encrypted payloads as something you can see but not read.
public enum GlyphAlphabet {
    /// All glyphs, in a fixed order so indices are stable across launches.
    public static let glyphs: [Character] = [
        // Braille
        "⠁", "⠃", "⠇", "⠏", "⠟", "⠿", "⠮", "⠭", "⠺", "⠵", "⠪", "⠔",
        // Box drawing
        "╋", "┼", "╬", "╠", "╣", "╦", "╩", "┏", "┛", "╭", "╯", "═", "║", "╱", "╲",
        // Katakana
        "ア", "カ", "サ", "タ", "ナ", "ハ", "マ", "ヤ", "ラ", "ワ", "ン", "キ", "シ", "ツ", "ヌ", "ミ",
        // Math operators
        "∀", "∂", "∃", "∅", "∇", "∈", "∏", "∑", "√", "∞", "∠", "∧", "∨", "∩", "∪", "∫",
        "≈", "≠", "≡", "≤", "⊕", "⊗", "⊥", "⋈", "⌬"
    ]

    /// Number of glyphs in the alphabet.
    public static var count: Int { glyphs.count }

    /// Glyph at `index` modulo the alphabet size.
    public static func glyph(at index: Int) -> Character {
        glyphs[((index % glyphs.count) + glyphs.count) % glyphs.count]
    }

    /// Produces a deterministic glyph string of `length` seeded by `seed`.
    /// The same seed always yields the same glyphs, so a message's cipher
    /// representation does not flicker between renders.
    public static func string(seeded seed: String, length: Int) -> String {
        guard length > 0 else { return "" }
        var state: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            state ^= UInt64(byte)
            state = state &* 0x0000_0100_0000_01b3
        }
        var out = String()
        out.reserveCapacity(length)
        for _ in 0..<length {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            out.append(glyph(at: Int(truncatingIfNeeded: state % UInt64(glyphs.count))))
        }
        return out
    }
}
