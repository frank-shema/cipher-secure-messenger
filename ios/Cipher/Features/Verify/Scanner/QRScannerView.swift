import AVFoundation
import SwiftUI
import UIKit

/// Live camera preview that reports every QR code it sees. The closure returns whether the code was
/// accepted: an accepted code freezes the session so the same code cannot fire twice while the sheet
/// is dismissing, a rejected one is muted for a moment so a code left in frame does not spam the hint.
struct QRScannerView: UIViewControllerRepresentable {
    let onCode: @MainActor (String) -> Bool
    let onFailure: @MainActor (CameraError) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(onCode: onCode, onFailure: onFailure)
    }

    func updateUIViewController(_ controller: QRScannerViewController, context: Context) {}
}

/// Hosts the preview layer and owns the capture session's lifetime: running while visible, stopped
/// otherwise, so the camera indicator never stays lit behind another screen.
final class QRScannerViewController: UIViewController {
    private let capture = CameraCaptureSession()
    private let previewView = CameraPreviewView()
    private let onCode: @MainActor (String) -> Bool
    private let onFailure: @MainActor (CameraError) -> Void
    private var hasAccepted = false
    private var lastRejected: (code: String, at: Date)?

    /// A rejected code is ignored for this long so the person can move the phone away before the
    /// hint re-triggers.
    private static let rejectionCooldown: TimeInterval = 2

    init(onCode: @escaping @MainActor (String) -> Bool, onFailure: @escaping @MainActor (CameraError) -> Void) {
        self.onCode = onCode
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.previewLayer?.session = capture.session
        previewView.previewLayer?.videoGravity = .resizeAspectFill
        previewView.isAccessibilityElement = true
        previewView.accessibilityLabel = String(localized: "verify.scanner.preview.a11y", defaultValue: "Camera viewfinder")
        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        capture.setHandlers(
            onCode: { [weak self] code in
                Task { @MainActor in self?.received(code) }
            },
            onFailure: { [weak self] failure in
                Task { @MainActor in self?.failed(failure) }
            }
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capture.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        capture.stop()
    }

    private func received(_ code: String) {
        guard !hasAccepted else { return }
        let now = Date()
        if let lastRejected, lastRejected.code == code, now.timeIntervalSince(lastRejected.at) < Self.rejectionCooldown {
            return
        }
        if onCode(code) {
            hasAccepted = true
            capture.stop()
            VerifyLog.scanner.info("code accepted")
        } else {
            lastRejected = (code, now)
        }
    }

    private func failed(_ failure: CameraError) {
        VerifyLog.scanner.error("camera failed: \(String(describing: failure), privacy: .public)")
        onFailure(failure)
    }
}

/// A view whose backing layer is the preview layer, so the camera image resizes with Auto Layout for free.
final class CameraPreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }
}

#Preview {
    QRScannerView(onCode: { _ in true }, onFailure: { _ in })
        .ignoresSafeArea()
}
