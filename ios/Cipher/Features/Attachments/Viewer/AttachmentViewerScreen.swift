import CipherCore
import CipherDesign
import SwiftUI

/// Destination for `Route.attachmentViewer`: a full-bleed image with zoom and share, or QuickLook for
/// any other file. View-once photos come through `ViewOnceLockedView` first, and the screen listens
/// for the system screenshot notification while one is open.
struct AttachmentViewerScreen: View {
    @State private var model: AttachmentViewerModel
    @Environment(\.dismiss) private var dismiss

    init(model: AttachmentViewerModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.6), for: .navigationBar)
        .toolbar {
            if let url = model.shareURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(String(localized: "attachments.viewer.share.a11y", defaultValue: "Share attachment"))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            model.screenshotTaken()
        }
        .task { await model.load() }
        .onDisappear { model.dismissed() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .tint(.white)
                .accessibilityLabel(String(localized: "attachments.viewer.loading.a11y", defaultValue: "Loading attachment"))
        case .locked:
            ViewOnceLockedView(thumbnail: model.attachment?.thumbnail) {
                Task { await model.reveal() }
            }
        case .fetching:
            AttachmentFetchingView(thumbnail: model.attachment?.thumbnail, progress: model.downloadProgress)
        case .image(let image, _):
            AttachmentImageViewer(image: image, caption: model.caption, isViewOnce: model.isViewOnce)
        case .file(let url):
            QuickLookPreview(url: url)
                .ignoresSafeArea(edges: .bottom)
        case .consumed:
            EmptyStateView(
                icon: "eye.slash",
                title: String(localized: "attachments.viewer.consumed.title", defaultValue: "Viewed once"),
                message: String(
                    localized: "attachments.viewer.consumed.message",
                    defaultValue: "This photo has been deleted from this device."
                )
            )
        case .unavailable(let reason):
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: String(localized: "attachments.viewer.unavailable.title", defaultValue: "Attachment unavailable"),
                message: reason,
                action: EmptyStateView.Action(title: String(localized: "common.ok", defaultValue: "OK")) { dismiss() }
            )
        }
    }

    private var title: String {
        if model.isViewOnce {
            return String(localized: "attachments.viewer.title.viewOnce", defaultValue: "View once")
        }
        return model.attachment?.filename ?? String(localized: "attachments.viewer.title", defaultValue: "Attachment")
    }
}

#Preview("Photo") {
    PreviewAttachmentHost { feature in
        NavigationStack {
            feature.viewer(for: PreviewAttachments.outgoingPhotoId)
        }
    }
}

#Preview("View once") {
    PreviewAttachmentHost { feature in
        NavigationStack {
            feature.viewer(for: PreviewAttachments.viewOncePhotoId)
        }
    }
}

#Preview("File") {
    PreviewAttachmentHost { feature in
        NavigationStack {
            feature.viewer(for: PreviewAttachments.fileId)
        }
    }
}
