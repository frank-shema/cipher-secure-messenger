import CipherCore
import CipherDesign
import Foundation
import Observation

/// The view-once ceremony for one incoming message: stays blurred until the person taps, records the
/// opening (once), tells the sender it was opened, reports a screenshot while it is on screen, and
/// deletes the message and its bytes when the viewer closes. Outgoing view-once media has no
/// ceremony here: the sender already holds the original and the thumbnail in the bubble.
@MainActor
@Observable
final class ViewOnceCoordinator {
    enum Phase: Hashable, Sendable {
        case locked
        case revealed
        case consumed
    }

    let message: Message
    private(set) var phase: Phase = .locked
    private(set) var hasReportedScreenshot = false
    /// The pixels were actually on screen. Deletion and screenshot reports are gated on this so a
    /// failed download after tapping never destroys a photo nobody saw.
    private(set) var hasPresented = false

    @ObservationIgnored private let marker: any ViewOnceMarking
    @ObservationIgnored private let sender: any MessageSending
    @ObservationIgnored private let messages: any MessageRepository
    @ObservationIgnored private let downloader: AttachmentDownloader
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let haptics: any HapticEngine
    @ObservationIgnored private var deletion: Task<Void, Never>?

    init(
        message: Message,
        marker: any ViewOnceMarking,
        sender: any MessageSending,
        messages: any MessageRepository,
        downloader: AttachmentDownloader,
        toasts: ToastCenter,
        haptics: any HapticEngine
    ) {
        self.message = message
        self.marker = marker
        self.sender = sender
        self.messages = messages
        self.downloader = downloader
        self.toasts = toasts
        self.haptics = haptics
    }

    /// Whether this message gets the blur-tap-delete treatment at all.
    var appliesCeremony: Bool {
        message.flags.viewOnce && message.direction == .incoming
    }

    /// After a relaunch a view-once message may still be on disk although it was opened before the
    /// app died. Returns `true` and finishes the deletion in that case, so it is never shown twice.
    func reconcileIfAlreadyViewed() async throws -> Bool {
        guard appliesCeremony, phase == .locked else { return false }
        guard try await marker.viewedAt(messageId: message.id) != nil else { return false }
        phase = .consumed
        AttachmentsLog.viewOnce.notice("view-once already opened earlier; finishing deletion")
        scheduleDeletion(after: .zero)
        return true
    }

    /// Records the opening before any bytes are fetched, so a crash between the two still counts as
    /// viewed. The `view_once_opened` notice goes out only on the first opening.
    func reveal() async throws {
        guard phase == .locked else { return }
        let first = try await marker.markViewed(messageId: message.id)
        phase = .revealed
        haptics.play(.whisperReveal)
        AttachmentsLog.viewOnce.info("view-once opened message=\(self.message.id.description, privacy: .public) first=\(first)")
        if first {
            notify(.viewOnceOpened)
        }
    }

    func presented() {
        guard phase == .revealed else { return }
        hasPresented = true
    }

    /// One report per viewing: the sender learns *that* a screenshot happened, not how many.
    func screenshotTaken() {
        guard phase == .revealed, hasPresented, !hasReportedScreenshot else { return }
        hasReportedScreenshot = true
        haptics.play(.warning)
        toasts.show(AttachmentToasts.screenshotReported)
        AttachmentsLog.viewOnce.notice("screenshot reported message=\(self.message.id.description, privacy: .public)")
        notify(.screenshotTaken)
    }

    /// Called when the viewer leaves the screen. Deletion waits for the pop animation so the bubble
    /// does not vanish under a transition that is still showing it.
    func close() {
        guard phase == .revealed, hasPresented else { return }
        phase = .consumed
        scheduleDeletion(after: .milliseconds(600))
    }

    private func scheduleDeletion(after delay: Duration) {
        let id = message.id
        deletion = Task { [messages, downloader, toasts] in
            try? await Task.sleep(for: delay)
            downloader.purge(messageId: id)
            do {
                try await messages.delete(ids: [id])
                toasts.show(AttachmentToasts.viewOnceDeleted)
                AttachmentsLog.viewOnce.info("view-once deleted message=\(id.description, privacy: .public)")
            } catch {
                AttachmentsLog.viewOnce.error("view-once delete failed message=\(id.description, privacy: .public)")
            }
        }
    }

    /// Sends the notice as an ordinary encrypted message: the relay cannot tell it from a text.
    private func notify(_ kind: SystemEvent.Kind) {
        let payload = MessagePayload.system(SystemEvent(kind: kind, refId: message.id))
        let conversationId = message.conversationId
        Task { [sender] in
            do {
                _ = try await sender.execute(conversationId: conversationId, payload: payload, expiresAt: nil)
            } catch {
                AttachmentsLog.viewOnce.error("system notice failed kind=\(kind.rawValue, privacy: .public)")
            }
        }
    }
}
