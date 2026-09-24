import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Thin ImageIO wrappers shared by the photo processor and the thumbnail generator. Everything here
/// is synchronous and CPU-bound; callers run it through `Task.detached`.
enum ImageEncoding {
    /// Decodes at most `maxPixelSize` on the longest side, with the EXIF orientation baked into the
    /// pixels. Baking the orientation is what lets the encoder drop the orientation tag along with
    /// every other piece of metadata without the photo coming out sideways.
    static func decode(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Encodes a JPEG carrying nothing but pixels: `CGImageDestinationAddImageAndMetadata` is given an
    /// explicit `nil` metadata block and a properties dictionary holding only the compression quality,
    /// so no EXIF, GPS, TIFF, IPTC or maker-note dictionary can be written.
    static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImageAndMetadata(destination, image, nil, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }

    static func source(for data: Data) -> CGImageSource? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        return source
    }
}
