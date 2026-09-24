import CipherCore
import Foundation
import Observation

/// Progress of every upload and download in flight, keyed by message id so a bubble, the viewer and
/// a future inbox indicator all read the same number. Lives on the main actor because its only
/// readers are views; the use cases report into it through `Sendable` closures that hop here.
@MainActor
@Observable
final class AttachmentTransferCenter {
    /// Fraction 0…1 per outgoing message whose attachment is still sealing, uploading or sending.
    private(set) var uploads: [MessageID: Double] = [:]
    /// Fraction 0…1 per message whose blob is downloading, verifying or decrypting.
    private(set) var downloads: [MessageID: Double] = [:]

    @ObservationIgnored private var uploadSubscribers: [UUID: AsyncStream<[MessageID: Double]>.Continuation] = [:]

    init() {}

    func report(_ messageId: MessageID, upload phase: AttachmentUploadPhase) {
        if phase.isTerminal {
            uploads.removeValue(forKey: messageId)
        } else {
            uploads[messageId] = phase.fraction
        }
        for continuation in uploadSubscribers.values {
            continuation.yield(uploads)
        }
    }

    func report(_ messageId: MessageID, download phase: AttachmentDownloadPhase) {
        switch phase {
        case .completed, .failed:
            downloads.removeValue(forKey: messageId)
        case .downloading, .verifying, .decrypting:
            downloads[messageId] = phase.fraction
        }
    }

    /// A stream that yields the whole upload map now and after every change. Each call creates an
    /// independent subscription; cancelling the consuming task removes it.
    func uploadUpdates() -> AsyncStream<[MessageID: Double]> {
        let (stream, continuation) = AsyncStream<[MessageID: Double]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let token = UUID()
        uploadSubscribers[token] = continuation
        continuation.yield(uploads)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.uploadSubscribers.removeValue(forKey: token) }
        }
        return stream
    }

    /// Progress callback for `SendAttachmentUseCase`, safe to invoke from any executor.
    nonisolated func uploadReporter() -> SendAttachmentUseCase.ProgressHandler {
        { [weak self] messageId, phase in
            Task { @MainActor in self?.report(messageId, upload: phase) }
        }
    }

    /// Progress callback for `FetchAttachmentUseCase`, safe to invoke from any executor.
    nonisolated func downloadReporter(for messageId: MessageID) -> FetchAttachmentUseCase.ProgressHandler {
        { [weak self] phase in
            Task { @MainActor in self?.report(messageId, download: phase) }
        }
    }
}
