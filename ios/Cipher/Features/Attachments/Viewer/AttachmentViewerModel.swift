import CipherCore
import Foundation
import Observation
import UIKit

/// What the viewer screen needs from the feature, gathered so previews can swap the lot.
@MainActor
struct AttachmentViewerPorts {
    var messages: any MessageRepository
    var downloader: AttachmentDownloader
    var transfers: AttachmentTransferCenter
    var makeViewOnce: (Message) -> ViewOnceCoordinator
}

/// Loads the message behind `Route.attachmentViewer`, runs the view-once ceremony when it applies,
/// and resolves the bytes to something a view can show: a decoded image or a file URL for QuickLook.
@MainActor
@Observable
final class AttachmentViewerModel {
    enum State {
        case loading
        case locked
        case fetching
        case image(UIImage, URL)
        case file(URL)
        case consumed
        case unavailable(String)
    }

    let messageId: MessageID
    private(set) var state: State = .loading
    private(set) var message: Message?
    private(set) var viewOnce: ViewOnceCoordinator?

    @ObservationIgnored private let ports: AttachmentViewerPorts

    init(messageId: MessageID, ports: AttachmentViewerPorts) {
        self.messageId = messageId
        self.ports = ports
    }

    var attachment: Attachment? {
        if case .attachment(let attachment, _) = message?.content { return attachment }
        return nil
    }

    var caption: String? {
        if case .attachment(_, let caption) = message?.content { return caption }
        return nil
    }

    var isViewOnce: Bool { viewOnce?.appliesCeremony == true }

    var downloadProgress: Double? { ports.transfers.downloads[messageId] }

    /// View-once bytes must not leave the app, so sharing is only offered for ordinary attachments.
    var shareURL: URL? {
        guard !isViewOnce else { return nil }
        switch state {
        case .image(_, let url), .file(let url): return url
        case .loading, .locked, .fetching, .consumed, .unavailable: return nil
        }
    }

    func load() async {
        guard case .loading = state else { return }
        do {
            guard let message = try await ports.messages.fetch(id: messageId) else {
                throw CipherCoreError.messageNotFound(messageId)
            }
            guard case .attachment(let attachment, _) = message.content else { throw AttachmentError.notAnAttachment(messageId) }
            self.message = message
            guard !attachment.sha256.isEmpty else {
                state = .unavailable(String(localized: "attachments.viewer.uploading", defaultValue: "This attachment is still uploading."))
                return
            }
            let coordinator = ports.makeViewOnce(message)
            viewOnce = coordinator
            if try await coordinator.reconcileIfAlreadyViewed() {
                state = .consumed
            } else if coordinator.appliesCeremony {
                state = .locked
            } else {
                await fetchAndPresent(message)
            }
        } catch {
            fail(error)
        }
    }

    func reveal() async {
        guard let viewOnce, let message, case .locked = state else { return }
        do {
            try await viewOnce.reveal()
            await fetchAndPresent(message)
        } catch {
            fail(error)
        }
    }

    func screenshotTaken() {
        viewOnce?.screenshotTaken()
    }

    func dismissed() {
        guard let viewOnce, viewOnce.appliesCeremony, viewOnce.hasPresented else { return }
        viewOnce.close()
        state = .consumed
    }

    private func fetchAndPresent(_ message: Message) async {
        state = .fetching
        do {
            let url = try await ports.downloader.localFile(for: message)
            if attachment?.mimeType.hasPrefix("image/") == true {
                guard let image = await Self.decodeImage(at: url) else { throw ImageProcessingError.unreadable }
                state = .image(image, url)
            } else {
                state = .file(url)
            }
            viewOnce?.presented()
        } catch {
            fail(error)
        }
    }

    /// Decoding happens off the main actor; `preparingForDisplay` pays the decompression cost once
    /// here instead of on the first frame of the zoom gesture.
    private static func decodeImage(at url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path())?.preparingForDisplay()
        }.value
    }

    private func fail(_ error: any Error) {
        let failure = String(describing: type(of: error))
        let id = messageId.description
        AttachmentsLog.viewer.error("viewer failed message=\(id, privacy: .public) error=\(failure, privacy: .public)")
        state = .unavailable(error.localizedDescription)
    }
}
