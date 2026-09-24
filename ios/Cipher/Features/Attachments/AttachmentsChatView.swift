import CipherCore
import CipherDesign
import SwiftUI

/// `ChatView` with the attachments feature installed: the photo picker and file importer are attached
/// to the screen and the view model's `onPickPhoto` / `onPickFile` callbacks are wired to them.
///
/// Drop-in replacement for `ChatView(viewModel:)` in the app's chat screen. With no feature (the decoy
/// inbox, or a runtime whose cache could not be created) it renders the plain chat: the composer's
/// attach buttons are still there and simply do nothing, and a staged send reports
/// `ChatError.attachmentsUnavailable`.
struct AttachmentsChatView: View {
    let viewModel: ChatViewModel
    let feature: AttachmentsFeature?

    @State private var composer: AttachmentComposerModel?

    init(viewModel: ChatViewModel, feature: AttachmentsFeature?) {
        self.viewModel = viewModel
        self.feature = feature
    }

    var body: some View {
        // One `ChatView` for both states: the composer arrives asynchronously, and rendering it in a
        // separate branch would recreate the chat and stop the view model's streams while the first
        // message snapshot is still in flight.
        ChatView(viewModel: viewModel)
            .attachmentPickers(composer)
            // Keyed on the view model so a rebuilt chat (surface swap, decoy toggle) gets its own
            // composer and the previous one's progress mirror is cancelled in its deinit.
            .task(id: ObjectIdentifier(viewModel)) {
                composer = feature?.attach(to: viewModel)
            }
    }
}

#Preview("With attachments") {
    PreviewAttachmentHost { feature in
        NavigationStack {
            AttachmentsChatView(viewModel: PreviewMessaging.chatViewModel(), feature: feature)
        }
    }
}

#Preview("Without attachments") {
    NavigationStack {
        AttachmentsChatView(viewModel: PreviewMessaging.chatViewModel(), feature: nil)
    }
    .toastHost()
}
