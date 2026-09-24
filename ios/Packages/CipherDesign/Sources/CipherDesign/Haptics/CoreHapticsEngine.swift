import Foundation
#if canImport(UIKit)
import CoreHaptics
import UIKit
#endif

/// Production haptic engine backed by Core Haptics, with graceful fallback to
/// UIKit feedback generators and automatic restart when the engine resets.
@MainActor
public final class CoreHapticsEngine: HapticEngine {
    #if canImport(UIKit)
    private var engine: CHHapticEngine?
    private var needsRestart = false
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    /// Creates the engine and starts Core Haptics if the device supports it.
    public init() {
        #if canImport(UIKit)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.needsRestart = true }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.needsRestart = true }
            }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
        #endif
    }

    public func play(_ pattern: HapticPattern) {
        #if canImport(UIKit)
        if playWithCoreHaptics(pattern) { return }
        playFallback(pattern)
        #endif
    }

    #if canImport(UIKit)
    private func playWithCoreHaptics(_ pattern: HapticPattern) -> Bool {
        guard let engine else { return false }
        do {
            if needsRestart {
                try engine.start()
                needsRestart = false
            }
            let events = HapticPatternLibrary.events(for: pattern).map(Self.chEvent)
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private static func chEvent(_ event: HapticEvent) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
        ]
        switch event.kind {
        case .transient:
            return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: event.time)
        case .continuous(let duration):
            return CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: event.time, duration: duration)
        }
    }

    private func playFallback(_ pattern: HapticPattern) {
        switch pattern {
        case .sent, .delivered, .read, .whisperReveal:
            impact.impactOccurred(intensity: pattern == .sent ? 0.6 : 0.45)
        case .verified, .capsuleUnlock:
            notification.notificationOccurred(.success)
        case .warning, .keyChanged:
            notification.notificationOccurred(.warning)
        case .lock:
            impact.impactOccurred(intensity: 1.0)
        }
    }
    #endif
}
