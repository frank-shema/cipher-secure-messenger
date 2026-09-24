import CipherCore
import CipherDesign
import Foundation
import SwiftUI
import UIKit

/// Builds an `AttachmentsFeature` over the messaging preview store, with the fixture photo and file
/// messages backed by real bytes so the viewer previews download, verify and render for real.
@MainActor
enum PreviewAttachments {
    static let outgoingPhotoId = MessagingFixtures.bobChat.messageId(.outgoing, counter: 4)
    static let viewOncePhotoId = MessagingFixtures.bobChat.messageId(.incoming, counter: 9)
    static let fileId = MessagingFixtures.bobChat.messageId(.incoming, counter: 3)

    /// A 1200×900 gradient with a "sun" and a dark band, the same motif as the fixture thumbnail.
    static let samplePhoto: UIImage = {
        let size = CGSize(width: 1_200, height: 900)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(red: 0.11, green: 0.36, blue: 0.42, alpha: 1).cgColor,
                          UIColor(red: 0.95, green: 0.62, blue: 0.29, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 750, y: 150, width: 230, height: 230)).fill()
            UIColor(white: 0.1, alpha: 0.55).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 650, width: size.width, height: 250)).fill()
        }
    }()

    static let samplePhotoJPEG: Data = samplePhoto.jpegData(compressionQuality: 0.85) ?? Data()

    /// A one-page PDF for the QuickLook preview.
    static let sampleDocument: Data = {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            let title = "Floor plan v3" as NSString
            title.draw(at: CGPoint(x: 48, y: 48), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28)])
            UIColor.systemTeal.setStroke()
            UIBezierPath(rect: CGRect(x: 48, y: 120, width: 516, height: 560)).stroke()
        }
    }()

    static let sampleDocumentURL: URL = {
        let url = FileManager.default.temporaryDirectory.appending(path: "cipher-preview-floor-plan.pdf")
        try? sampleDocument.write(to: url, options: .atomic)
        return url
    }()

    /// A feature over a seeded preview store whose attachment messages resolve to real blobs.
    static func seededFeature() async -> AttachmentsFeature? {
        let bundle = PreviewMessaging.bundle()
        let blobs = PreviewBlobGateway()
        let crypto = PreviewAttachmentCrypto()
        let hasher = CryptoKitBlobHasher()
        let ports = AttachmentPorts(
            accountId: MessagingFixtures.me.id,
            messages: bundle.store,
            conversations: bundle.store,
            outbox: PreviewOutbox(),
            crypto: crypto,
            conversationGateway: PreviewConversationGateway(),
            blobs: blobs,
            viewOnce: PreviewViewOnceMarker(),
            hasher: hasher
        )
        await seedBlobs(in: bundle.store, blobs: blobs, crypto: crypto, hasher: hasher)
        guard let feature = try? AttachmentsFeature(ports: ports, toasts: ToastCenter()) else { return nil }
        feature.removeCachedFiles()
        return feature
    }

    private static func seedBlobs(
        in store: PreviewMessagingStore,
        blobs: PreviewBlobGateway,
        crypto: PreviewAttachmentCrypto,
        hasher: CryptoKitBlobHasher
    ) async {
        let thread = (try? await store.fetch(conversationId: MessagingFixtures.bobConversationId, limit: 100, before: nil)) ?? []
        for var message in thread {
            guard case .attachment(var attachment, let caption) = message.content else { continue }
            let plaintext = attachment.mimeType.hasPrefix("image/") ? samplePhotoJPEG : sampleDocument
            guard let sealed = try? crypto.sealBlob(plaintext, key: attachment.key) else { continue }
            await blobs.seed(sealed, as: attachment.blobId)
            attachment.sha256 = hasher.sha256Hex(sealed)
            attachment.size = plaintext.count
            message.content = .attachment(attachment, caption: caption)
            try? await store.upsert(message)
        }
    }
}

/// Waits for the seeded feature, then renders `content` with it. Keeps viewer previews honest: the
/// bytes shown really went through download, digest check and decryption.
struct PreviewAttachmentHost<Content: View>: View {
    @State private var feature: AttachmentsFeature?
    let content: (AttachmentsFeature) -> Content

    init(@ViewBuilder content: @escaping (AttachmentsFeature) -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if let feature {
                content(feature)
                    .environment(feature.toasts)
                    .toastHost()
            } else {
                ProgressView()
                    .task { feature = await PreviewAttachments.seededFeature() }
            }
        }
    }
}

#Preview("Composer in chat") {
    PreviewAttachmentHost { feature in
        let viewModel = PreviewMessaging.chatViewModel()
        let composer = feature.attach(to: viewModel)
        NavigationStack {
            ChatView(viewModel: viewModel)
                .attachmentPickers(composer)
        }
    }
}
