import CipherCore
import CipherDesign
import Foundation
import Observation

/// Façade over the attachments feature for one signed-in account. The integrator builds one per
/// session, passes `sender` into `ChatDependencies` (as both `sender` and `attachments`), calls
/// `attach(to:)` when a `ChatViewModel` is created, and resolves `Route.attachmentViewer` through
/// `viewer(for:)`. Everything else (pickers, metadata stripping, sealing, progress, view-once,
/// screenshot reporting, the protected cache) stays behind this type.
@MainActor
@Observable
final class AttachmentsFeature {
    let transfers = AttachmentTransferCenter()
    let toasts: ToastCenter
    let cache: AttachmentCache

    @ObservationIgnored private let ports: AttachmentPorts
    @ObservationIgnored private let drafts = StagedDraftStore()
    @ObservationIgnored private let sendUseCase: SendAttachmentUseCase
    @ObservationIgnored private let downloader: AttachmentDownloader
    @ObservationIgnored private let importer: AttachmentImporter
    @ObservationIgnored private let haptics: any HapticEngine

    init(
        ports: AttachmentPorts,
        toasts: ToastCenter,
        haptics: any HapticEngine = NoopHapticEngine(),
        importer: AttachmentImporter = AttachmentImporter()
    ) throws(AttachmentCacheError) {
        self.ports = ports
        self.toasts = toasts
        self.haptics = haptics
        self.importer = importer
        self.cache = try AttachmentCache(accountId: ports.accountId)
        self.sendUseCase = SendAttachmentUseCase(
            currentUserId: ports.accountId,
            messages: ports.messages,
            conversations: ports.conversations,
            outbox: ports.outbox,
            crypto: ports.crypto,
            conversationGateway: ports.conversationGateway,
            blobs: ports.blobs,
            hasher: ports.hasher,
            clock: ports.clock
        )
        let fetch = FetchAttachmentUseCase(blobs: ports.blobs, crypto: ports.crypto, hasher: ports.hasher)
        self.downloader = AttachmentDownloader(fetch: fetch, cache: cache, transfers: transfers)
    }

    /// The chat's `MessageSending` *and* `AttachmentSending`. One object for both so a retry on a
    /// failed upload re-uploads the retained bytes instead of re-sealing the placeholder.
    var sender: AttachmentSendAdapter {
        AttachmentSendAdapter(useCase: sendUseCase, drafts: drafts, transfers: transfers)
    }

    /// Installs the pick callbacks on the ViewModel and mirrors upload progress into it. Apply the
    /// returned composer to the chat view with `.attachmentPickers(_:)`.
    func attach(to viewModel: ChatViewModel) -> AttachmentComposerModel {
        let conversationId = viewModel.conversationId
        let composer = AttachmentComposerModel(
            importer: importer,
            onPrepared: { [weak self, weak viewModel] outcome in
                self?.stage(outcome, conversationId: conversationId, in: viewModel)
            },
            onFailed: { [weak self] error in
                if case .tooLarge = error {
                    self?.toasts.show(AttachmentToasts.fileTooLarge)
                } else {
                    self?.toasts.show(AttachmentToasts.preparingFailed(error.localizedDescription))
                }
            }
        )
        viewModel.onPickPhoto = { [weak composer] in composer?.presentPhotoPicker() }
        viewModel.onPickFile = { [weak composer] in composer?.presentFileImporter() }
        composer.progressMirror = Task { [weak viewModel, transfers] in
            for await snapshot in transfers.uploadUpdates() {
                guard let viewModel else { return }
                viewModel.uploadProgress = snapshot
            }
        }
        return composer
    }

    /// The screen for `Route.attachmentViewer(messageId)`.
    func viewer(for messageId: MessageID) -> AttachmentViewerScreen {
        let viewerPorts = AttachmentViewerPorts(
            messages: ports.messages,
            downloader: downloader,
            transfers: transfers,
            makeViewOnce: { [self] message in
                ViewOnceCoordinator(
                    message: message,
                    marker: ports.viewOnce,
                    sender: sender,
                    messages: ports.messages,
                    downloader: downloader,
                    toasts: toasts,
                    haptics: haptics
                )
            }
        )
        return AttachmentViewerScreen(model: AttachmentViewerModel(messageId: messageId, ports: viewerPorts))
    }

    /// Sign-out hook: drops every decrypted file of this account.
    func removeCachedFiles() {
        cache.removeAll()
        AttachmentsLog.transfer.info("attachment cache cleared for account \(self.ports.accountId.description, privacy: .public)")
    }

    private func stage(_ outcome: AttachmentImporter.Outcome, conversationId: ConversationID, in viewModel: ChatViewModel?) {
        let draft = outcome.draft
        let staged = StagedAttachment(
            filename: draft.filename,
            mimeType: draft.mimeType,
            size: draft.size,
            previewImageData: draft.thumbnail
        )
        Task { [drafts, weak viewModel] in
            await drafts.store(draft, id: staged.id, conversationId: conversationId)
            viewModel?.stage(staged)
        }
        if outcome.strippedLocation {
            haptics.play(.lock)
            toasts.show(AttachmentToasts.locationRemoved)
        } else if outcome.strippedCameraMetadata {
            toasts.show(AttachmentToasts.metadataRemoved)
        }
    }
}
