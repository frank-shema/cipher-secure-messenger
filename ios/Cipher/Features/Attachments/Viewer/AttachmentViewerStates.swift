import CipherCore
import CipherDesign
import SwiftUI

/// The blurred gate in front of an unopened view-once photo. The copy says exactly what tapping does,
/// because the consequence (deletion on close) is not something a person can undo.
struct ViewOnceLockedView: View {
    let thumbnail: Data?
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: CipherSpacing.xl) {
            ZStack {
                if let thumbnail, let image = UIImage(data: thumbnail) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 28)
                        .accessibilityHidden(true)
                }
                ViewOnceOverlay(hint: String(localized: "attachments.viewOnce.tapHint", defaultValue: "Tap to view once"))
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: CipherRadius.lg))
            .onTapGesture(perform: onReveal)
            Text(String(
                localized: "attachments.viewOnce.explainer",
                defaultValue: """
                This photo opens once. It is deleted from this device when you close it, \
                and the sender is told if you take a screenshot.
                """
            ))
            .font(CipherTypography.caption)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.horizontal, CipherSpacing.xl)
            CipherButton(
                String(localized: "attachments.viewOnce.open", defaultValue: "View once"),
                systemImage: "eye",
                action: onReveal
            )
                .padding(.horizontal, CipherSpacing.xxl)
                .accessibilityHint(String(localized: "attachments.viewOnce.open.a11y.hint", defaultValue: "Opens the photo one time"))
        }
    }
}

/// Download, verify and decrypt progress over the blurred thumbnail, so the shape of the photo is
/// already there when the pixels arrive.
struct AttachmentFetchingView: View {
    let thumbnail: Data?
    let progress: Double?

    var body: some View {
        ZStack {
            if let thumbnail, let image = UIImage(data: thumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 18)
                    .opacity(0.6)
                    .accessibilityHidden(true)
            }
            AttachmentProgressRing(progress: progress ?? 0, size: 64)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "attachments.viewer.downloading.a11y", defaultValue: "Downloading and decrypting attachment"))
    }
}

/// A photo with an optional caption and the view-once reminder badge.
struct AttachmentImageViewer: View {
    let image: UIImage
    let caption: String?
    let isViewOnce: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ZoomableImageView(image: image)
            VStack(spacing: CipherSpacing.sm) {
                if isViewOnce {
                    Label(
                        String(localized: "attachments.viewOnce.badge", defaultValue: "Viewing once · deleted when you close"),
                        systemImage: "eye.slash"
                    )
                    .font(CipherTypography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, CipherSpacing.md)
                    .padding(.vertical, CipherSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(CipherTypography.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(CipherSpacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CipherRadius.md))
                }
            }
            .padding(.bottom, CipherSpacing.xl)
            .padding(.horizontal, CipherSpacing.lg)
        }
    }
}

#Preview("Locked") {
    ZStack {
        Color.black.ignoresSafeArea()
        ViewOnceLockedView(thumbnail: MessagingFixtures.sampleThumbnail) {}
    }
}

#Preview("Fetching") {
    ZStack {
        Color.black.ignoresSafeArea()
        AttachmentFetchingView(thumbnail: MessagingFixtures.sampleThumbnail, progress: 0.42)
    }
}

#Preview("Image") {
    AttachmentImageViewer(image: PreviewAttachments.samplePhoto, caption: "The second page is the one to look at", isViewOnce: true)
        .background(Color.black)
}
