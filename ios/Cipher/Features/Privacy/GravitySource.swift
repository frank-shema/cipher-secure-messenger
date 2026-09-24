import CoreMotion
import Foundation

/// Where the flip-to-hide monitor reads the gravity vector from. Abstracted so the simulator and
/// previews, which have no motion hardware, can drive the same monitor by hand.
@MainActor
protocol GravitySource: AnyObject {
    /// False when there is no motion hardware to read (simulator, some accessibility configurations).
    var isAvailable: Bool { get }
    /// Starts delivering the z component of gravity every `interval` seconds. Starting twice is harmless.
    func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (Double) -> Void)
    func stop()
}

/// Core Motion device-motion updates. Device motion is preferred over the raw accelerometer because
/// the sensor fusion has already separated gravity from user acceleration, so a phone placed face up
/// mid-stride does not read as face down for a frame.
@MainActor
final class DeviceGravitySource: GravitySource {
    private let manager = CMMotionManager()

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (Double) -> Void) {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = interval
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let gravityZ = motion?.gravity.z else { return }
            MainActor.assumeIsolated { handler(gravityZ) }
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }
}

/// Hand-driven readings for previews and the simulator: `emit(gravityZ: 1)` is face down, `-1` face up.
@MainActor
final class PreviewGravitySource: GravitySource {
    let isAvailable: Bool
    private var handler: (@MainActor @Sendable (Double) -> Void)?

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (Double) -> Void) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func emit(gravityZ: Double) {
        handler?(gravityZ)
    }
}
