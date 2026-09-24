import CipherDesign
import PhotosUI
import SwiftUI

/// Attaches the system photo picker and file importer to a chat screen and shows a "Preparing"
/// pill while a pick is downscaled and stripped. Apply once to `ChatView`.
///
/// The composer is optional so the chat keeps one view identity whether or not attachments are
/// available: swapping the wrapped view in and out of a conditional branch would recreate `ChatView`
/// and tear down its live streams mid-flight. Without a composer the pickers are simply never presented.
struct AttachmentPickersModifier: ViewModifier {
    let composer: AttachmentComposerModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: isPhotoPickerPresented,
                selection: photoSelection,
                matching: .images,
                photoLibrary: .shared()
            )
            .fileImporter(
                isPresented: isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false,
                onCompletion: { composer?.handleFileImport($0) }
            )
            .overlay(alignment: .top) {
                if composer?.isPreparing == true {
                    PreparingPill()
                        .padding(.top, CipherSpacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: composer?.isPreparing ?? false)
    }

    private var isPhotoPickerPresented: Binding<Bool> {
        Binding(
            get: { composer?.isPhotoPickerPresented ?? false },
            set: { composer?.isPhotoPickerPresented = $0 }
        )
    }

    private var isFileImporterPresented: Binding<Bool> {
        Binding(
            get: { composer?.isFileImporterPresented ?? false },
            set: { composer?.isFileImporterPresented = $0 }
        )
    }

    private var photoSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { composer?.photoSelection },
            set: { composer?.photoSelection = $0 }
        )
    }
}

/// Small capsule that says what is happening to the photo before it can be sent.
struct PreparingPill: View {
    var body: some View {
        HStack(spacing: CipherSpacing.sm) {
            ProgressView()
                .tint(CipherColor.accent)
                .controlSize(.small)
            Text(String(localized: "attachments.composer.preparing", defaultValue: "Removing metadata…"))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textPrimary)
        }
        .padding(.horizontal, CipherSpacing.md)
        .padding(.vertical, CipherSpacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(CipherColor.divider))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "attachments.composer.preparing.a11y", defaultValue: "Preparing attachment"))
    }
}

extension View {
    /// Installs the pickers `AttachmentsFeature.attach(to:)` drives for a chat screen. Pass `nil`
    /// while there is no composer yet: the view keeps its identity and the pickers stay dormant.
    func attachmentPickers(_ composer: AttachmentComposerModel?) -> some View {
        modifier(AttachmentPickersModifier(composer: composer))
    }
}

#Preview {
    let composer = AttachmentComposerModel(onPrepared: { _ in }, onFailed: { _ in })
    VStack(spacing: CipherSpacing.lg) {
        PreparingPill()
        CipherButton("Pick photo", systemImage: "photo") { composer.presentPhotoPicker() }
        CipherButton("Pick file", systemImage: "doc", variant: .ghost) { composer.presentFileImporter() }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CipherColor.background)
    .attachmentPickers(composer)
}
