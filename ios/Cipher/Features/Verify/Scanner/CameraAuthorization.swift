import AVFoundation
import Foundation

/// Camera permission as the scanner screen needs it. `unavailable` covers the Simulator and devices
/// without a rear camera, where asking for permission would be misleading: the screen falls back to
/// pasting the payload instead.
enum CameraAuthorization: Hashable, Sendable {
    case undetermined
    case authorized
    case denied
    case restricted
    case unavailable

    static var current: CameraAuthorization {
        #if targetEnvironment(simulator)
        return .unavailable
        #else
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            return .unavailable
        }
        return map(AVCaptureDevice.authorizationStatus(for: .video))
        #endif
    }

    /// Prompts once; iOS remembers the answer, so later calls return immediately.
    static func request() async -> CameraAuthorization {
        guard current == .undetermined else { return current }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    var canScan: Bool {
        self == .authorized
    }

    private static func map(_ status: AVAuthorizationStatus) -> CameraAuthorization {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .undetermined
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}
