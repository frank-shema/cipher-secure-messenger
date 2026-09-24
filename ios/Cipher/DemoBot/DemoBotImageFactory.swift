#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws the picture Echo sends back for `photo`: a seeded two-tone gradient with a few soft discs,
/// rendered by CoreGraphics into a PNG plus a small JPEG thumbnail.
///
/// The image is synthesised in memory, so it starts with no camera, location or timestamp metadata,
/// and the encoder is handed an empty property dictionary so it adds none. That is the point of the
/// demo attachment: the only description of it that exists travels inside the message ciphertext.
enum DemoBotImageFactory {
    struct Rendered: Sendable {
        let png: Data
        let thumbnail: Data?
        let width: Int
        let height: Int
    }

    static let side = 640
    static let thumbnailSide = 96
    /// PROTOCOL.md §3 caps the inline thumbnail at 24 KiB.
    static let thumbnailLimit = 24 * 1_024

    /// Runs wherever it is called; callers keep it off the main actor (the responder does).
    static func render(seed: UInt64) throws(DemoBotError) -> Rendered {
        var random = DemoBotRandom(seed: seed)
        let palette = Palette(using: &random)
        let discs = Disc.scatter(count: 5, using: &random)
        let image = try draw(palette: palette, discs: discs)
        let png = try encode(image, as: .png, quality: nil)
        let thumbnail = try? encodeThumbnail(of: image)
        let thumbnailBytes = thumbnail?.count ?? 0
        DemoBotLog.image.info("rendered \(side)x\(side) png of \(png.count) bytes, thumbnail \(thumbnailBytes) bytes")
        return Rendered(png: png, thumbnail: thumbnail, width: side, height: side)
    }

    // MARK: - Drawing

    private static func draw(palette: Palette, discs: [Disc]) throws(DemoBotError) -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = makeContext(side: side, space: space),
              let gradient = CGGradient(colorsSpace: space, colors: [palette.start, palette.end] as CFArray, locations: [0, 1])
        else { throw .imageGenerationFailed }
        let extent = CGFloat(side)
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: extent, y: extent), options: [])
        for disc in discs {
            context.setFillColor(disc.color)
            context.fillEllipse(in: disc.rect(in: extent))
        }
        guard let image = context.makeImage() else { throw .imageGenerationFailed }
        return image
    }

    private static func makeContext(side: Int, space: CGColorSpace) -> CGContext? {
        CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }

    // MARK: - Encoding

    private static func encode(_ image: CGImage, as type: UTType, quality: Double?) throws(DemoBotError) -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            throw .imageGenerationFailed
        }
        var properties: [CFString: Any] = [:]
        if let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .imageGenerationFailed }
        return output as Data
    }

    /// Down-samples and re-encodes at falling quality until the thumbnail fits the protocol's limit.
    private static func encodeThumbnail(of image: CGImage) throws(DemoBotError) -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = makeContext(side: thumbnailSide, space: space) else {
            throw .imageGenerationFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: thumbnailSide, height: thumbnailSide))
        guard let small = context.makeImage() else { throw .imageGenerationFailed }
        for quality in [0.7, 0.5, 0.35, 0.2] {
            let jpeg = try encode(small, as: .jpeg, quality: quality)
            if jpeg.count <= thumbnailLimit {
                return jpeg
            }
        }
        throw .imageGenerationFailed
    }

    // MARK: - Ingredients

    private struct Palette {
        let start: CGColor
        let end: CGColor

        init(using random: inout DemoBotRandom) {
            let hue = Double.random(in: 0..<1, using: &random)
            let offset = 0.3 + Double.random(in: 0..<0.25, using: &random)
            let secondHue = (hue + offset).truncatingRemainder(dividingBy: 1)
            start = DemoBotImageFactory.color(hue: hue, saturation: 0.62, brightness: 0.96)
            end = DemoBotImageFactory.color(hue: secondHue, saturation: 0.78, brightness: 0.58)
        }
    }

    private struct Disc {
        let x: Double
        let y: Double
        let radius: Double
        let alpha: Double

        var color: CGColor {
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
        }

        func rect(in extent: CGFloat) -> CGRect {
            let diameter = extent * radius
            return CGRect(x: extent * x - diameter / 2, y: extent * y - diameter / 2, width: diameter, height: diameter)
        }

        static func scatter(count: Int, using random: inout DemoBotRandom) -> [Disc] {
            (0..<count).map { _ in
                Disc(
                    x: Double.random(in: 0.1...0.9, using: &random),
                    y: Double.random(in: 0.1...0.9, using: &random),
                    radius: Double.random(in: 0.18...0.45, using: &random),
                    alpha: Double.random(in: 0.08...0.22, using: &random)
                )
            }
        }
    }

    /// HSB → sRGB without UIKit, so the factory stays a pure CoreGraphics unit.
    private static func color(hue: Double, saturation: Double, brightness: Double) -> CGColor {
        let sector = hue * 6
        let fraction = sector - Double(Int(sector))
        let low = brightness * (1 - saturation)
        let falling = brightness * (1 - saturation * fraction)
        let rising = brightness * (1 - saturation * (1 - fraction))
        let channels: [Double] = switch Int(sector) % 6 {
        case 0: [brightness, rising, low]
        case 1: [falling, brightness, low]
        case 2: [low, brightness, rising]
        case 3: [low, falling, brightness]
        case 4: [rising, low, brightness]
        default: [brightness, low, falling]
        }
        return CGColor(srgbRed: channels[0], green: channels[1], blue: channels[2], alpha: 1)
    }
}
#endif
