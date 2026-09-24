import CipherDesign
import CoreGraphics
import Testing

struct CipherDesignTests {
    @Test func spacingScaleIsStrictlyIncreasing() {
        let scale: [CGFloat] = [
            CipherSpacing.xs,
            CipherSpacing.sm,
            CipherSpacing.md,
            CipherSpacing.lg,
            CipherSpacing.xl,
            CipherSpacing.xxl
        ]
        #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func radiusScaleIsStrictlyIncreasing() {
        let scale: [CGFloat] = [CipherRadius.sm, CipherRadius.md, CipherRadius.lg]
        #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
    }
}
