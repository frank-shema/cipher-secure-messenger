import CipherCore
import CipherDesign
import SwiftUI

/// Destination for `Route.attachmentViewer(messageId)`: the feature's viewer when the account has
/// one, otherwise a calm explanation. The decoy inbox reaches this with `feature == nil` because its
/// fictional attachments have no blobs behind them, and that must look like an ordinary limitation
/// rather than a broken screen.
struct AttachmentViewerRoute: View {
    let messageId: MessageID
    let feature: AttachmentsFeature?

    var body: some View {
        if let feature {
            feature.viewer(for: messageId)
        } else {
            ZStack {
                CipherColor.background.ignoresSafeArea()
                EmptyStateView(
                    icon: "paperclip",
                    title: String(localized: "attachments.route.unavailable.title", defaultValue: "Attachment unavailable"),
                    message: String(
                        localized: "attachments.route.unavailable.message",
                        defaultValue: "This attachment cannot be opened on this device right now."
                    )
                )
            }
            .navigationTitle(String(localized: "attachments.route.title", defaultValue: "Attachment"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("File") {
    PreviewAttachmentHost { feature in
        NavigationStack {
            AttachmentViewerRoute(messageId: PreviewAttachments.fileId, feature: feature)
        }
    }
}

#Preview("Unavailable") {
    NavigationStack {
        AttachmentViewerRoute(messageId: PreviewAttachments.fileId, feature: nil)
    }
}
