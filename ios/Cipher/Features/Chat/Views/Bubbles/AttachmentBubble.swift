import CipherCore
import CipherDesign
import SwiftUI

/// Photo or file bubble. Images render their embedded thumbnail (decoded lazily by UIKit); files
/// show a document card. View-once media hides behind `ViewOnceOverlay` until tapped, and an upload
/// in flight shows the progress ring the attachments feature reports.
struct AttachmentBubble: View {
    let message: Message
    let attachment: Attachment
    let caption: String?
    let tail: MessageBubbleShape.Tail
    let progress: Double?
    let onTap: () -> Void

    private var isImage: Bool { attachment.mimeType.hasPrefix("image/") }
    private var hidesBehindViewOnce: Bool { message.flags.viewOnce && message.direction == .incoming }

    private var aspectRatio: CGFloat {
        guard let width = attachment.width, let height = attachment.height, height > 0 else { return 4 / 3 }
        return CGFloat(width) / CGFloat(height)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: CipherSpacing.xs) {
                if isImage {
                    imageBody
                } else {
                    fileBody
                }
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(CipherTypography.body)
                        .foregroundStyle(message.direction.primaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BubbleMetaView(message: message)
            }
        }
        .buttonStyle(.plain)
        .bubbleChrome(direction: message.direction, tail: tail)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "chat.attachment.a11y.hint", defaultValue: "Opens the attachment"))
    }

    private var imageBody: some View {
        ZStack {
            if hidesBehindViewOnce {
                ViewOnceOverlay(hint: String(localized: "chat.attachment.viewOnce.hint", defaultValue: "Tap to view once"))
            } else if let data = attachment.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: CipherRadius.md).fill(CipherGradient.violet)
                    GlyphRain(isAnimated: false, tint: .white.opacity(0.6))
                }
            }
            if let progress {
                AttachmentProgressRing(progress: progress)
            } else if message.status == .sending {
                ProgressView().tint(.white)
            }
            if message.flags.viewOnce, message.direction == .outgoing {
                Image(systemName: "eye.fill")
                    .font(.caption.weight(.bold))
                    .padding(CipherSpacing.xs + 2)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(CipherSpacing.sm)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 232, height: 232 / aspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: CipherRadius.md))
    }

    private var fileBody: some View {
        HStack(spacing: CipherSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CipherRadius.sm).fill(message.direction.primaryTextColor.opacity(0.12))
                if let progress {
                    AttachmentProgressRing(progress: progress, size: 30)
                } else {
                    Image(systemName: "doc.fill").font(.title3)
                }
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(MessageFormatting.fileSize(attachment.size))
                    .font(.caption)
                    .foregroundStyle(message.direction.secondaryTextColor)
            }
        }
        .foregroundStyle(message.direction.primaryTextColor)
        .frame(minWidth: 200, alignment: .leading)
    }

    private var accessibilityLabel: String {
        if hidesBehindViewOnce {
            return String(localized: "chat.attachment.a11y.viewOnce", defaultValue: "View-once photo, not yet opened")
        }
        return isImage
            ? String(localized: "chat.attachment.a11y.photo", defaultValue: "Encrypted photo")
            : String(localized: "chat.attachment.a11y.file", defaultValue: "Encrypted file \(attachment.filename)")
    }
}

#Preview {
    let messages = PreviewMessaging.sampleMessages.filter { if case .attachment = $0.content { true } else { false } }
    ScrollView {
        VStack(spacing: CipherSpacing.md) {
            ForEach(messages) { message in
                if case .attachment(let attachment, let caption) = message.content {
                    AttachmentBubble(message: message, attachment: attachment, caption: caption,
                                     tail: message.direction == .outgoing ? .trailing : .leading,
                                     progress: message.status == .sending ? 0.6 : nil) {}
                        .frame(maxWidth: .infinity, alignment: message.direction == .outgoing ? .trailing : .leading)
                }
            }
        }
        .padding()
    }
    .background(CipherColor.background)
}
