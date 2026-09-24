import CipherCore
import Foundation
import ImageIO

/// A photo ready to seal, plus what was removed from it so the UI can say so.
struct ProcessedImage: Sendable {
    var jpeg: Data
    var width: Int
    var height: Int
    /// The original carried a GPS dictionary (a location fix), now gone.
    var hadLocation: Bool
    /// The original carried EXIF, TIFF, IPTC or maker-note data (camera, lens, software), now gone.
    var hadCameraMetadata: Bool
}

enum ImageProcessingError: Error, LocalizedError, Hashable, Sendable {
    case unreadable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            String(localized: "attachments.error.unreadableImage", defaultValue: "This image could not be read.")
        case .encodingFailed:
            String(localized: "attachments.error.encodingFailed", defaultValue: "This image could not be prepared for sending.")
        }
    }
}

/// Downscales a photo to at most 2048 px on its longest side and re-encodes it as a JPEG with no
/// metadata. Re-encoding is unconditional: even a small photo goes through the destination so its
/// location, camera and software tags are dropped rather than copied.
struct ImageProcessor: Sendable {
    var maxDimension = AttachmentLimits.maxImageDimension
    var quality = 0.82

    /// Runs on a detached task: decoding a 48-megapixel HEIC is not main-actor work.
    func process(_ data: Data) async throws(ImageProcessingError) -> ProcessedImage {
        let processor = self
        let outcome: Result<ProcessedImage, ImageProcessingError> = await Task.detached(priority: .userInitiated) {
            Result { () throws(ImageProcessingError) in try processor.processSynchronously(data) }
        }.value
        return try outcome.get()
    }

    func processSynchronously(_ data: Data) throws(ImageProcessingError) -> ProcessedImage {
        guard let source = ImageEncoding.source(for: data) else { throw .unreadable }
        let inspection = MetadataInspector.inspect(source)
        guard let image = ImageEncoding.decode(source, maxPixelSize: maxDimension) else { throw .unreadable }
        guard let jpeg = ImageEncoding.jpeg(image, quality: quality) else { throw .encodingFailed }
        let dimensions = "\(image.width)x\(image.height)"
        AttachmentsLog.processing.info(
            "photo processed in=\(data.count) out=\(jpeg.count) size=\(dimensions, privacy: .public) gps=\(inspection.hasLocation)"
        )
        return ProcessedImage(
            jpeg: jpeg,
            width: image.width,
            height: image.height,
            hadLocation: inspection.hasLocation,
            hadCameraMetadata: inspection.hasCameraMetadata
        )
    }
}

/// Reads which metadata dictionaries a source carries, without reading their contents: the feature
/// only needs to know *that* a location was present, never where.
enum MetadataInspector {
    struct Inspection: Sendable {
        var hasLocation: Bool
        var hasCameraMetadata: Bool
    }

    static func inspect(_ source: CGImageSource) -> Inspection {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let cameraKeys = [
            kCGImagePropertyExifDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyIPTCDictionary,
            kCGImagePropertyMakerAppleDictionary,
            kCGImagePropertyExifAuxDictionary
        ]
        return Inspection(
            hasLocation: isPopulated(properties[kCGImagePropertyGPSDictionary as String]),
            hasCameraMetadata: cameraKeys.contains { isPopulated(properties[$0 as String]) }
        )
    }

    private static func isPopulated(_ value: Any?) -> Bool {
        guard let dictionary = value as? [String: Any] else { return false }
        return !dictionary.isEmpty
    }
}
