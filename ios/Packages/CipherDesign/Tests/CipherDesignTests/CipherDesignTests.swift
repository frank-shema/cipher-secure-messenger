import CipherDesign
import CoreGraphics
import Testing

struct CipherDesignTests {
    @Test func spacingScaleIsStrictlyIncreasing() {
        let scale: [CGFloat] = [
            CipherSpacing.xs, CipherSpacing.sm, CipherSpacing.md,
            CipherSpacing.lg, CipherSpacing.xl, CipherSpacing.xxl
        ]
        #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func radiusScaleIsStrictlyIncreasing() {
        let scale: [CGFloat] = [CipherRadius.sm, CipherRadius.md, CipherRadius.lg]
        #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func typographyBaseSizesAreOrdered() {
        #expect(CipherTypography.BaseSize.title > CipherTypography.BaseSize.headline)
        #expect(CipherTypography.BaseSize.headline >= CipherTypography.BaseSize.body)
        #expect(CipherTypography.BaseSize.body > CipherTypography.BaseSize.caption)
        #expect(CipherTypography.BaseSize.mono > CipherTypography.BaseSize.monoSmall)
    }

    @Test func avatarHueIsDeterministicAndBounded() {
        let a = AvatarIdentity.hue(for: "ada@cipher.app")
        let b = AvatarIdentity.hue(for: "ada@cipher.app")
        let c = AvatarIdentity.hue(for: "grace@cipher.app")
        #expect(a == b)
        #expect(a != c)
        #expect((0..<1).contains(a))
        #expect(AvatarIdentity.initials(from: "Ada Lovelace") == "AL")
    }

    @Test func glyphAlphabetIsUniqueAndStable() {
        #expect(Set(GlyphAlphabet.glyphs).count == GlyphAlphabet.glyphs.count)
        #expect(GlyphAlphabet.count >= 60)
        #expect(GlyphAlphabet.string(seeded: "hello", length: 12) == GlyphAlphabet.string(seeded: "hello", length: 12))
        #expect(GlyphText.render("two words").count == "two words".count)
    }
}
