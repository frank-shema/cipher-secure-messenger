import CipherCore
import CipherDesign
import SwiftUI

/// The strip above the text field: sensitive-content suggestion, the message being replied to, and
/// the staged attachment. Each element is optional and animates in on its own.
struct ComposerAccessories: View {
    @Bindable var viewModel: ChatViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: CipherSpacing.sm) {
            if let finding = viewModel.sensitiveFinding {
                SensitiveSuggestionChip(suggestion: SensitiveSuggestion(kind: finding, confidence: 1),
                                        onAccept: viewModel.acceptSensitiveSuggestion,
                                        onDismiss: viewModel.dismissSensitiveSuggestion)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let replyingTo = viewModel.replyingTo {
                replyChip(replyingTo)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let staged = viewModel.stagedAttachment {
                stagedPreview(staged)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion),
                   value: [viewModel.sensitiveFinding != nil, viewModel.replyingTo != nil, viewModel.stagedAttachment != nil])
    }

    private func replyChip(_ message: Message) -> some View {
        HStack(spacing: CipherSpacing.sm) {
            ReplyQuoteView(quoted: message, contactName: viewModel.contact.user.displayName, direction: .incoming, isCompact: true)
            Button {
                viewModel.replyingTo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CipherColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "chat.composer.reply.cancel", defaultValue: "Cancel reply"))
        }
    }

    private func stagedPreview(_ staged: StagedAttachment) -> some View {
        HStack(spacing: CipherSpacing.md) {
            ZStack {
                if let data = staged.previewImageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: CipherRadius.sm).fill(CipherColor.surfaceElevated)
                    Image(systemName: "doc.fill").foregroundStyle(CipherColor.textSecondary)
                }
                if viewModel.composer.viewOnce {
                    ViewOnceOverlay(hint: "")
                        .scaleEffect(0.5)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: CipherRadius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text(staged.filename)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CipherColor.textPrimary)
                    .lineLimit(1)
                Text(MessageFormatting.fileSize(staged.size))
                    .font(.caption)
                    .foregroundStyle(CipherColor.textSecondary)
            }
            Spacer()
            Button {
                viewModel.stagedAttachment = nil
                viewModel.composer.viewOnce = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CipherColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "chat.composer.attachment.remove", defaultValue: "Remove attachment"))
        }
        .padding(CipherSpacing.sm)
        .background(CipherColor.surface, in: RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous).strokeBorder(CipherColor.divider))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "chat.composer.attachment.a11y", defaultValue: "Attached \(staged.filename)"))
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel(sensitive: .cardNumber)
    VStack {
        Spacer()
        ComposerAccessories(viewModel: viewModel)
            .padding()
    }
    .background(CipherColor.background)
    .task {
        viewModel.draft = "4111 1111 1111 1111"
        viewModel.replyingTo = PreviewMessaging.sampleMessages.first
        viewModel.stage(StagedAttachment(filename: "IMG_2048.jpg", mimeType: "image/jpeg", size: 184_320,
                                         previewImageData: MessagingFixtures.sampleThumbnail))
    }
}
