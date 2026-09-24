import AVFoundation
import Foundation

/// Why the camera could not be started. Surfaced as copy on the scanner screen.
enum CameraError: Error, LocalizedError, Hashable, Sendable {
    case noCamera
    case inputRejected
    case outputRejected

    var errorDescription: String? {
        switch self {
        case .noCamera:
            String(localized: "verify.scanner.error.noCamera", defaultValue: "No camera is available on this device.")
        case .inputRejected:
            String(localized: "verify.scanner.error.input", defaultValue: "The camera could not be opened.")
        case .outputRejected:
            String(localized: "verify.scanner.error.output", defaultValue: "This device cannot read QR codes.")
        }
    }
}

/// Owns an `AVCaptureSession` configured for QR codes and confines every call to one serial queue.
///
/// `startRunning()` blocks for hundreds of milliseconds, so it must never run on the main thread;
/// `AVCaptureSession` is not `Sendable`, so the session must never be touched from two isolation
/// domains. Routing all access through `queue` satisfies both, which is what justifies the
/// `@unchecked Sendable` conformance: the session is reachable only via this queue.
final class CameraCaptureSession: NSObject, @unchecked Sendable {
    /// Read-only handle for `AVCaptureVideoPreviewLayer`; the layer only observes the session.
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.cipher.app.camera", qos: .userInitiated)
    private let output = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var codeHandler: (@Sendable (String) -> Void)?
    private var failureHandler: (@Sendable (CameraError) -> Void)?

    /// Installs the callbacks on the capture queue so they are visible to the delegate without a race.
    func setHandlers(onCode: @escaping @Sendable (String) -> Void, onFailure: @escaping @Sendable (CameraError) -> Void) {
        queue.async {
            self.codeHandler = onCode
            self.failureHandler = onFailure
        }
    }

    func start() {
        queue.async {
            if !self.isConfigured {
                do throws(CameraError) {
                    try self.configure()
                    self.isConfigured = true
                } catch {
                    self.failureHandler?(error)
                    return
                }
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() throws(CameraError) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw .noCamera
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw .inputRejected
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard session.canAddInput(input) else { throw .inputRejected }
        session.addInput(input)
        guard session.canAddOutput(output) else { throw .outputRejected }
        session.addOutput(output)
        guard output.availableMetadataObjectTypes.contains(.qr) else { throw .outputRejected }
        output.metadataObjectTypes = [.qr]
        output.setMetadataObjectsDelegate(self, queue: queue)
    }
}

extension CameraCaptureSession: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject, code.type == .qr, let value = code.stringValue else {
                continue
            }
            codeHandler?(value)
            return
        }
    }
}
