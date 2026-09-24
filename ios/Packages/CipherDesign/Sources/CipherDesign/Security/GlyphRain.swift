import SwiftUI

/// Columns of cipher glyphs drifting downward, drawn in a single `Canvas`.
///
/// Every frame is a pure function of time and column index, so the rain is
/// deterministic and inexpensive. When `isAnimated` is `false` it renders a
/// single static frame, which is what Reduce Motion gets.
public struct GlyphRain: View {
    private let isAnimated: Bool
    private let tint: Color
    private let columnSpacing: CGFloat

    /// Creates glyph rain.
    /// - Parameters:
    ///   - isAnimated: Whether glyphs drift; pass `false` for a still frame.
    ///   - tint: Colour of the glyphs; it is drawn at low opacity.
    ///   - columnSpacing: Horizontal distance between glyph columns.
    public init(isAnimated: Bool = true, tint: Color = CipherColor.accent, columnSpacing: CGFloat = 22) {
        self.isAnimated = isAnimated
        self.tint = tint
        self.columnSpacing = columnSpacing
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isAnimated)) { context in
            let time = isAnimated ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas(rendersAsynchronously: true) { graphics, size in
                draw(in: &graphics, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let glyphSize: CGFloat = 14
        let columns = Int(size.width / columnSpacing) + 1
        for column in 0..<columns {
            let speed = 18 + CipherGlyphs.unit(index: column, frame: 1) * 26
            let phase = CipherGlyphs.unit(index: column, frame: 2) * Double(size.height)
            let length = 5 + Int(CipherGlyphs.unit(index: column, frame: 3) * 9)
            let head = (time * speed + phase).truncatingRemainder(dividingBy: Double(size.height) + Double(length) * glyphSize)
            let x = CGFloat(column) * columnSpacing + columnSpacing / 2
            for offset in 0..<length {
                let y = CGFloat(head) - CGFloat(offset) * glyphSize
                guard y > -glyphSize, y < size.height + glyphSize else { continue }
                let frame = Int(time * 6) + offset
                let glyph = String(CipherGlyphs.glyph(index: column * 97 + offset, frame: frame))
                let fade = 1 - Double(offset) / Double(length)
                context.opacity = (offset == 0 ? 0.55 : 0.28) * fade
                context.draw(
                    Text(glyph).font(.system(size: glyphSize - 2, weight: .medium, design: .monospaced)).foregroundStyle(tint),
                    at: CGPoint(x: x, y: y)
                )
            }
        }
    }
}

#Preview("GlyphRain") {
    GlyphRain()
        .background(CipherColor.background)
}
