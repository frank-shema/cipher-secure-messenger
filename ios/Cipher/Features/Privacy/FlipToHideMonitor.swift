import Foundation
import Observation
import SwiftUI

/// Watches whether the phone is lying face down, the universal "not right now" gesture for someone
/// reading over your shoulder, and publishes `isHidden` for `privacyGuard` to act on.
///
/// Sampling at 10 Hz is more than enough to catch a deliberate flip while keeping the motion
/// coprocessor cost negligible. A hysteresis band between the hide and show thresholds stops the
/// curtain flickering while the phone rocks to rest on a table. Without motion hardware the monitor is
/// inert: `isSupported` is false and `isHidden` never becomes true.
@MainActor
@Observable
final class FlipToHideMonitor {
    /// Gravity z above this reads as face down (+1 is fully face down, -1 fully face up).
    static let hideThreshold = 0.8
    /// Gravity z must drop below this before the content shows again.
    static let showThreshold = 0.5
    static let sampleInterval: TimeInterval = 0.1

    private static let enabledKey = "cipher.privacy.flipToHideEnabled"

    private(set) var isHidden = false
    private(set) var isMonitoring = false

    /// Person-facing switch, persisted. Default on: the feature costs nothing until the phone is flipped.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                if sceneIsActive { start() }
            } else {
                stop()
            }
        }
    }

    var isSupported: Bool {
        source.isAvailable
    }

    @ObservationIgnored private let source: any GravitySource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var sceneIsActive = false

    init(source: (any GravitySource)? = nil, defaults: UserDefaults = .standard) {
        self.source = source ?? DeviceGravitySource()
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.enabledKey) == nil ? true : defaults.bool(forKey: Self.enabledKey)
    }

    /// Begins sampling. Safe to call repeatedly; a no-op when disabled or unsupported.
    func start() {
        guard isEnabled, isSupported, !isMonitoring else { return }
        isMonitoring = true
        source.start(interval: Self.sampleInterval) { [weak self] gravityZ in
            self?.observe(gravityZ: gravityZ)
        }
        PrivacyLog.flipToHide.debug("monitoring started")
    }

    /// Stops sampling and reveals the content, so a stale "hidden" state never survives a background trip.
    func stop() {
        guard isMonitoring else { return }
        source.stop()
        isMonitoring = false
        isHidden = false
        PrivacyLog.flipToHide.debug("monitoring stopped")
    }

    /// Sampling only makes sense while the scene is on screen; the privacy curtain covers the rest.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            sceneIsActive = true
            start()
        case .inactive, .background:
            sceneIsActive = false
            stop()
        @unknown default:
            sceneIsActive = false
            stop()
        }
    }

    private func observe(gravityZ: Double) {
        if !isHidden, gravityZ > Self.hideThreshold {
            isHidden = true
            PrivacyLog.flipToHide.info("content hidden")
        } else if isHidden, gravityZ < Self.showThreshold {
            isHidden = false
            PrivacyLog.flipToHide.info("content shown")
        }
    }
}
