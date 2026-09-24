import SwiftUI
#if canImport(UIKit)
import CoreImage.CIFilterBuiltins
import UIKit
#endif

/// Renders `payload` as a crisp QR code on a light card so scanners always
/// see dark modules on a light field, regardless of appearance.
public struct QRCodeView: View {
    private let payload: String
    private let size: CGFloat

    /// Creates a QR code.
    /// - Parameters:
    ///   - payload: UTF-8 string to encode.
    ///   - size: Rendered edge length in points.
    public init(payload: String, size: CGFloat = 220) {
        self.payload = payload
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CipherRadius.lg)
                .fill(Color.white)
            content
                .padding(CipherSpacing.lg)
        }
        .frame(width: size, height: size)
        .cipherShadow(.medium)
        .accessibilityLabel(Text("QR code"))
        .accessibilityValue(Text("Scan to verify keys"))
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(UIKit)
        if let image = QRCodeView.image(for: payload) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            unavailable
        }
        #else
        unavailable
        #endif
    }

    private var unavailable: some View {
        Image(systemName: "qrcode")
            .font(.system(size: size * 0.4))
            .foregroundStyle(Color(hex: 0x0B0F1A))
    }

    #if canImport(UIKit)
    /// Generates a QR image for `payload` using `CIQRCodeGenerator`.
    static func image(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif
}

#Preview {
    QRCodeView(payload: "cipher://verify/3f9a2c...")
        .padding(CipherSpacing.xl)
        .background(CipherColor.background)
}
