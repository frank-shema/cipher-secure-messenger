import CipherDesign
import SwiftUI

/// Pinch-to-zoom and pan for a single image, with double-tap to toggle 2.5× and rubber-band-free
/// clamping so the picture never drifts off screen. Gestures are plain SwiftUI so the view stays
/// self-contained and previewable.
struct ZoomableImageView: View {
    let image: UIImage
    var minScale: CGFloat = 1
    var maxScale: CGFloat = 5

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnify(in: proxy.size).simultaneously(with: pan(in: proxy.size)))
                .onTapGesture(count: 2) { toggleZoom(in: proxy.size) }
                .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: scale)
                .accessibilityLabel(String(localized: "attachments.viewer.image.a11y", defaultValue: "Photo"))
                .accessibilityHint(String(
                    localized: "attachments.viewer.image.a11y.hint",
                    defaultValue: "Pinch to zoom, double tap to toggle zoom"
                ))
                .accessibilityAddTraits(.isImage)
        }
        .clipped()
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = clampedScale(steadyScale * value.magnification)
                offset = clampedOffset(steadyOffset, in: size)
            }
            .onEnded { _ in
                steadyScale = scale
                steadyOffset = clampedOffset(offset, in: size)
                offset = steadyOffset
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: scale > 1 ? 0 : 20)
            .onChanged { value in
                guard scale > 1 else { return }
                let proposed = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, in: size)
            }
            .onEnded { _ in
                steadyOffset = offset
            }
    }

    private func toggleZoom(in size: CGSize) {
        let target: CGFloat = scale > 1 ? 1 : 2.5
        scale = target
        steadyScale = target
        offset = .zero
        steadyOffset = .zero
    }

    private func clampedScale(_ proposed: CGFloat) -> CGFloat {
        min(max(proposed, minScale), maxScale)
    }

    /// Keeps the scaled image covering the viewport: once zoomed in, the visible edge may never pull
    /// past the image edge, and at 1× the image sits centred.
    private func clampedOffset(_ proposed: CGSize, in size: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let fitted = fittedSize(in: size)
        let maxX = max((fitted.width * scale - size.width) / 2, 0)
        let maxY = max((fitted.height * scale - size.height) / 2, 0)
        return CGSize(width: min(max(proposed.width, -maxX), maxX), height: min(max(proposed.height, -maxY), maxY))
    }

    private func fittedSize(in size: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return size }
        let ratio = min(size.width / image.size.width, size.height / image.size.height)
        return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    }
}

#Preview {
    ZoomableImageView(image: PreviewAttachments.samplePhoto)
        .background(Color.black)
        .ignoresSafeArea()
}
