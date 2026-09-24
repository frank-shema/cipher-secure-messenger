import CipherCore
import Foundation
import ImageIO

/// Produces the ≤ 24 KiB JPEG preview that travels inside the message payload. It steps down quality
/// first and dimensions second, because a slightly softer 320 px preview reads better in a bubble
/// than a crisp 128 px one.
struct ThumbnailGenerator: Sendable {
    var maxBytes = AttachmentLimits.maxThumbnailBytes
    var dimensions = [AttachmentLimits.thumbnailDimension, 256, 192, 128]
    var qualities = [0.7, 0.55, 0.42, 0.3]

    /// Returns nil only when the input cannot be decoded at all; the search space always ends in a
    /// 128 px, quality 0.3 image, which is far below the ceiling for any photographic content.
    func thumbnail(fromJPEG data: Data) async -> Data? {
        let generator = self
        return await Task.detached(priority: .userInitiated) { generator.thumbnailSynchronously(fromJPEG: data) }.value
    }

    func thumbnailSynchronously(fromJPEG data: Data) -> Data? {
        guard let source = ImageEncoding.source(for: data) else { return nil }
        for dimension in dimensions {
            guard let image = ImageEncoding.decode(source, maxPixelSize: dimension) else { continue }
            for quality in qualities {
                if let jpeg = ImageEncoding.jpeg(image, quality: quality), jpeg.count <= maxBytes {
                    return jpeg
                }
            }
        }
        AttachmentsLog.processing.notice("thumbnail exceeded \(maxBytes, privacy: .public) bytes at every step; omitted")
        return nil
    }
}
