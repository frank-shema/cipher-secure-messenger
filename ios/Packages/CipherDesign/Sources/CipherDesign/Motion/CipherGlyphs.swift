import Foundation

/// The cipher glyph alphabet and a deterministic pseudo-random source shared by
/// every scrambling effect, so animations are reproducible and cheap.
public enum CipherGlyphs {
    /// Glyphs chosen to read as "encrypted": mathematical, block and box-drawing symbols.
    public static let alphabet: [Character] = Array("ΔΞΨΩΣΦΛΓ∂∇∑∫≈≠≡⊕⊗⊘◊◈▚▞░▒▓█#%&@0123456789")

    /// A deterministic 64-bit hash of the given components (SplitMix64 finalizer).
    ///
    /// The same inputs always produce the same output, which keeps every frame
    /// of an effect reproducible in previews, tests and on device.
    public static func hash(_ seed: UInt64, _ index: Int, _ frame: Int) -> UInt64 {
        var state = seed &+ 0x9E37_79B9_7F4A_7C15 &* UInt64(truncatingIfNeeded: index &+ 1)
        state &+= 0xBF58_476D_1CE4_E5B9 &* UInt64(truncatingIfNeeded: frame &+ 1)
        state = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
        state = (state ^ (state >> 27)) &* 0x94D0_49BB_1331_11EB
        return state ^ (state >> 31)
    }

    /// A deterministic glyph for a character position at a given animation frame.
    public static func glyph(index: Int, frame: Int, seed: UInt64 = 0) -> Character {
        let value = hash(seed, index, frame)
        return alphabet[Int(value % UInt64(alphabet.count))]
    }

    /// A unit-interval value in `0..<1` derived from the same hash.
    public static func unit(index: Int, frame: Int, seed: UInt64 = 0) -> Double {
        Double(hash(seed, index, frame) >> 11) / Double(1 << 53)
    }

    /// Replaces every non-whitespace character with a cipher glyph.
    public static func scramble(_ text: String, frame: Int = 0, seed: UInt64 = 0) -> String {
        String(text.enumerated().map { offset, character in
            character.isWhitespace || character.isNewline
                ? character
                : glyph(index: offset, frame: frame, seed: seed)
        })
    }

    /// A stable seed derived from a string, so the same text always scrambles the same way.
    public static func seed(for text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
    }
}
