import CipherCore
import Foundation
import Observation
import PhotosUI
import SwiftUI

/// Drives the photo picker and file importer for one chat screen and turns a pick into a staged
/// draft. Presentation flags live here so `ChatViewModel.onPickPhoto/onPickFile` are one-liners.
@MainActor
@Observable
final class AttachmentComposerModel {
    var isPhotoPickerPresented = false
    var isFileImporterPresented = false
    var photoSelection: PhotosPickerItem? {
        didSet {
            guard let item = photoSelection else { return }
            photoSelection = nil
            load(item)
        }
    }
    /// True while bytes are being read, downscaled and stripped; the composer shows a small pill.
    private(set) var isPreparing = false

    @ObservationIgnored private let importer: AttachmentImporter
    @ObservationIgnored private let onPrepared: @MainActor (AttachmentImporter.Outcome) -> Void
    @ObservationIgnored private let onFailed: @MainActor (AttachmentImportError) -> Void
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored var progressMirror: Task<Void, Never>?

    init(
        importer: AttachmentImporter = AttachmentImporter(),
        onPrepared: @escaping @MainActor (AttachmentImporter.Outcome) -> Void,
        onFailed: @escaping @MainActor (AttachmentImportError) -> Void
    ) {
        self.importer = importer
        self.onPrepared = onPrepared
        self.onFailed = onFailed
    }

    deinit {
        preparation?.cancel()
        progressMirror?.cancel()
    }

    func presentPhotoPicker() {
        isPhotoPickerPresented = true
    }

    func presentFileImporter() {
        isFileImporterPresented = true
    }

    /// `fileImporter` completion. A cancelled sheet reports no error.
    func handleFileImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            prepare { (importer: AttachmentImporter) async throws(AttachmentImportError) -> AttachmentImporter.Outcome in
                try await importer.importFile(at: url)
            }
        case .failure:
            onFailed(.accessDenied)
        }
    }

    private func load(_ item: PhotosPickerItem) {
        prepare { (importer: AttachmentImporter) async throws(AttachmentImportError) -> AttachmentImporter.Outcome in
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                throw AttachmentImportError.unreadable
            }
            return try await importer.importPhoto(data)
        }
    }

    private typealias Preparation = (AttachmentImporter) async throws(AttachmentImportError) -> AttachmentImporter.Outcome

    private func prepare(_ work: @escaping Preparation) {
        preparation?.cancel()
        isPreparing = true
        let importer = importer
        preparation = Task { [weak self] in
            defer { self?.isPreparing = false }
            let outcome: Result<AttachmentImporter.Outcome, AttachmentImportError>
            do throws(AttachmentImportError) {
                outcome = .success(try await work(importer))
            } catch {
                outcome = .failure(error)
            }
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let prepared):
                AttachmentsLog.composer.info(
                    "staged attachment bytes=\(prepared.draft.size, privacy: .public) image=\(prepared.draft.isImage, privacy: .public)"
                )
                self?.onPrepared(prepared)
            case .failure(let error):
                AttachmentsLog.composer.error("attachment import failed: \(String(describing: error), privacy: .public)")
                self?.onFailed(error)
            }
        }
    }
}
