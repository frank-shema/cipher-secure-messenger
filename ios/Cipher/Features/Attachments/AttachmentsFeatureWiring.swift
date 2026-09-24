import CipherCore
import CipherDesign
import CipherNetworking
import CipherPersistence
import Foundation

/// The composition root's one call into the attachments feature.
///
/// `AccountRuntime` builds the feature once per signed-in account from the things it already has
/// (the `MessagingStack`, the relay client, the account store) and then hands it to three places:
/// `ChatDependencies` (through `withAttachments(_:)`), the chat screen (`AttachmentsChatView`) and the
/// `Route.attachmentViewer` destination (`AttachmentViewerRoute`). Nothing else needs to know that
/// sealing, uploading, metadata stripping, view-once and the protected cache exist.
enum AttachmentsFeatureWiring {
    /// Production wiring over the concrete account graph: the relay's attachment routes on the
    /// account's `APIClient` and the SwiftData store as the durable view-once record.
    ///
    /// Throws only when the per-account cache directory cannot be created; callers may fall back to
    /// `attachments: nil` in `ChatDependencies`, which keeps text messaging working.
    @MainActor
    static func make(
        stack: MessagingStack,
        client: APIClient,
        store: PersistenceStore,
        toasts: ToastCenter,
        haptics: any HapticEngine
    ) throws(AttachmentCacheError) -> AttachmentsFeature {
        try make(
            stack: stack,
            attachmentGateway: RemoteAttachmentGateway(client: client),
            viewOnce: store,
            toasts: toasts,
            haptics: haptics
        )
    }

    /// Port-level wiring, for a runtime that already holds an `AttachmentGateway` and a
    /// `ViewOnceMarking` (or wants to substitute either).
    @MainActor
    static func make(
        stack: MessagingStack,
        attachmentGateway: any AttachmentGateway,
        viewOnce: any ViewOnceMarking,
        toasts: ToastCenter,
        haptics: any HapticEngine
    ) throws(AttachmentCacheError) -> AttachmentsFeature {
        let ports = AttachmentPorts(
            stack: stack,
            blobs: NetworkingAttachmentBlobGateway(gateway: attachmentGateway),
            viewOnce: viewOnce
        )
        let feature = try AttachmentsFeature(ports: ports, toasts: toasts, haptics: haptics)
        AttachmentsLog.transfer.info("attachments wired for \(stack.account.id.description, privacy: .public)")
        return feature
    }
}

extension ChatDependencies {
    /// The same bundle with the feature's adapter installed as both `sender` and `attachments`.
    ///
    /// One object serves both ports on purpose: a retry on an attachment whose upload failed must
    /// re-upload the retained bytes, which only the attachments adapter can do, while every plain
    /// text send still goes through Core's `SendMessageUseCase` underneath. The disappearing-timer
    /// use case built by `init` keeps the original sender; both reach the same outbox.
    @MainActor
    func withAttachments(_ feature: AttachmentsFeature) -> ChatDependencies {
        var wired = self
        let sender = feature.sender
        wired.sender = sender
        wired.attachments = sender
        return wired
    }
}
