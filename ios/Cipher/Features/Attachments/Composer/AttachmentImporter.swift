import CipherCore
import Foundation
import UniformTypeIdentifiers

enum AttachmentImportError: Error, LocalizedError, Hashable, Sendable {
    case accessDenied
    case unreadable
    case empty
    case tooLarge(bytes: Int)
    case image(ImageProcessingError)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "attachments.error.accessDenied", defaultValue: "Cipher was not allowed to read that file.")
        case .unreadable:
            String(localized: "attachments.error.unreadable", defaultValue: "That file could not be read.")
        case .empty:
            String(localized: "attachments.error.empty", defaultValue: "That file is empty.")
        case .tooLarge:
            String(localized: "attachments.error.tooLarge", defaultValue: "That file is over the 25 MB limit.")
        case .image(let error):
            error.errorDescription
        }
    }
}

/// Turns a pick (photo bytes or a file URL) into an `AttachmentDraft`. Every image, whatever its
/// origin, goes through `ImageProcessor` so a JPEG chosen from Files loses its location just like
/// one chosen from Photos; other files are sent byte-for-byte.
struct AttachmentImporter: Sendable {
    struct Outcome: Sendable {
        var draft: AttachmentDraft
        var strippedLocation: Bool
        var strippedCameraMetadata: Bool
    }

    var processor = ImageProcessor()
    var thumbnails = ThumbnailGenerator()
    var maxBytes = AttachmentLimits.maxPlaintextBytes

    func importPhoto(_ data: Data, preferredName: String? = nil) async throws(AttachmentImportError) -> Outcome {
        guard !data.isEmpty else { throw .empty }
        let processed: ProcessedImage
        do {
            processed = try await processor.process(data)
        } catch {
            throw .image(error)
        }
        guard processed.jpeg.count <= maxBytes else { throw .tooLarge(bytes: processed.jpeg.count) }
        let thumbnail = await thumbnails.thumbnail(fromJPEG: processed.jpeg)
        let draft = AttachmentDraft(
            data: processed.jpeg,
            mimeType: "image/jpeg",
            filename: Self.photoFilename(preferred: preferredName),
            width: processed.width,
            height: processed.height,
            thumbnail: thumbnail
        )
        return Outcome(draft: draft, strippedLocation: processed.hadLocation, strippedCameraMetadata: processed.hadCameraMetadata)
    }

    /// Reads a security-scoped URL from `fileImporter`. Access is released before returning, so the
    /// bytes are copied into memory rather than mapped.
    func importFile(at url: URL) async throws(AttachmentImportError) -> Outcome {
        let (data, type) = try await Self.read(url, limit: maxBytes)
        if let type, type.conforms(to: .image) {
            return try await importPhoto(data, preferredName: url.deletingPathExtension().lastPathComponent)
        }
        let draft = AttachmentDraft(
            data: data,
            mimeType: type?.preferredMIMEType ?? "application/octet-stream",
            filename: url.lastPathComponent
        )
        return Outcome(draft: draft, strippedLocation: false, strippedCameraMetadata: false)
    }

    private static func read(_ url: URL, limit: Int) async throws(AttachmentImportError) -> (Data, UTType?) {
        let outcome: Result<(Data, UTType?), AttachmentImportError> = await Task.detached(priority: .userInitiated) {
            Result { () throws(AttachmentImportError) in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isReadableKey])
                if values?.isReadable == false { throw .accessDenied }
                if let size = values?.fileSize, size > limit { throw .tooLarge(bytes: size) }
                guard let data = try? Data(contentsOf: url) else { throw .unreadable }
                guard !data.isEmpty else { throw .empty }
                guard data.count <= limit else { throw .tooLarge(bytes: data.count) }
                let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
                return (data, type)
            }
        }.value
        return try outcome.get()
    }

    /// Photos from the library have no user-visible name; a timestamped one keeps downloads on the
    /// other side distinguishable without leaking the library's internal identifier.
    static func photoFilename(preferred: String?, now: Date = Date()) -> String {
        if let preferred, !preferred.isEmpty {
            return preferred + ".jpg"
        }
        let stamp = now.formatted(Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted))
        return "Photo-\(stamp).jpg"
    }
}
