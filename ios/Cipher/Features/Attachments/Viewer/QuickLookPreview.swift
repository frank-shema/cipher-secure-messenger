import QuickLook
import SwiftUI

/// QuickLook for decrypted files (PDFs, documents, audio) embedded in the viewer route. The file
/// lives in the protected attachment cache; QuickLook reads it in place and never copies it out.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    /// The delegate conformance is main-actor isolated: QuickLook calls it on the main thread and the
    /// coordinator's state is only touched from there.
    @MainActor
    final class Coordinator: NSObject, QLPreviewControllerDataSource, @MainActor QLPreviewControllerDelegate {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }

        /// Read-only: markup would write a modified copy next to the decrypted original.
        func previewController(
            _ controller: QLPreviewController,
            editingModeFor previewItem: any QLPreviewItem
        ) -> QLPreviewItemEditingMode {
            .disabled
        }
    }
}

#Preview {
    QuickLookPreview(url: PreviewAttachments.sampleDocumentURL)
        .ignoresSafeArea()
}
