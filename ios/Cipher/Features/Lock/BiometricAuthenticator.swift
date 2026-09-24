import Foundation
import LocalAuthentication

/// Which biometric the device offers, for labelling the unlock button honestly.
enum BiometryKind: Hashable, Sendable {
    case none
    case touchID
    case faceID
    case opticID

    var title: String {
        switch self {
        case .none: String(localized: "lock.biometry.none", defaultValue: "Biometrics")
        case .touchID: String(localized: "lock.biometry.touchID", defaultValue: "Touch ID")
        case .faceID: String(localized: "lock.biometry.faceID", defaultValue: "Face ID")
        case .opticID: String(localized: "lock.biometry.opticID", defaultValue: "Optic ID")
        }
    }

    var systemImage: String {
        switch self {
        case .none: "lock"
        case .touchID: "touchid"
        case .faceID: "faceid"
        case .opticID: "opticid"
        }
    }
}

struct BiometricCapability: Hashable, Sendable {
    var kind: BiometryKind
    var isAvailable: Bool

    static let unavailable = BiometricCapability(kind: .none, isAvailable: false)
}

enum BiometricOutcome: Hashable, Sendable {
    case success
    case cancelled
    /// The person tapped the fallback button; show the PIN pad.
    case fallbackToPIN
    case failed
    case unavailable
}

protocol BiometricAuthenticating: Sendable {
    func capability() -> BiometricCapability
    func authenticate(reason: String) async -> BiometricOutcome
}

/// `LocalAuthentication` wrapper. Biometrics are tried first; when they are locked out after too many
/// failed scans the device passcode is offered instead, because a locked-out sensor should not strand
/// the owner on a PIN they may have chosen years ago. A fresh `LAContext` per call avoids the cached
/// "already authenticated" state that would otherwise let a second prompt succeed silently.
struct BiometricAuthenticator: BiometricAuthenticating {
    func capability() -> BiometricCapability {
        let context = LAContext()
        var probe: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &probe)
        let kind: BiometryKind
        switch context.biometryType {
        case .touchID: kind = .touchID
        case .faceID: kind = .faceID
        case .opticID: kind = .opticID
        case .none: kind = .none
        @unknown default: kind = .none
        }
        return BiometricCapability(kind: kind, isAvailable: available && kind != .none)
    }

    func authenticate(reason: String) async -> BiometricOutcome {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "lock.biometric.fallback", defaultValue: "Use PIN")
        var probe: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &probe) else {
            if let probe, LAError.Code(rawValue: probe.code) == .biometryLockout {
                return await evaluate(.deviceOwnerAuthentication, reason: reason, context: context)
            }
            return .unavailable
        }
        return await evaluate(.deviceOwnerAuthenticationWithBiometrics, reason: reason, context: context)
    }

    private func evaluate(_ policy: LAPolicy, reason: String, context: LAContext) async -> BiometricOutcome {
        do {
            let granted = try await context.evaluatePolicy(policy, localizedReason: reason)
            return granted ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return .cancelled
            case .userFallback:
                return .fallbackToPIN
            case .biometryLockout where policy == .deviceOwnerAuthenticationWithBiometrics:
                return await evaluate(.deviceOwnerAuthentication, reason: reason, context: context)
            default:
                LockLog.lock.notice("biometric evaluation failed code=\(error.code.rawValue, privacy: .public)")
                return .failed
            }
        } catch {
            return .failed
        }
    }
}

/// Fixed answers for previews.
struct PreviewBiometricAuthenticator: BiometricAuthenticating {
    var stubCapability = BiometricCapability(kind: .faceID, isAvailable: true)
    var outcome: BiometricOutcome = .success

    func capability() -> BiometricCapability {
        stubCapability
    }

    func authenticate(reason: String) async -> BiometricOutcome {
        try? await Task.sleep(for: .milliseconds(400))
        return outcome
    }
}
