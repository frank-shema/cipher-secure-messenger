import Foundation

/// Semantic haptic moments in Cipher. Each maps to a distinct tactile
/// signature so security events can be felt without looking.
public enum HapticPattern: String, Sendable, CaseIterable, Hashable {
    /// Message left the device.
    case sent
    /// Message reached the recipient's device.
    case delivered
    /// Recipient opened the message.
    case read
    /// Safety number confirmed.
    case verified
    /// Something needs attention.
    case warning
    /// A contact's identity key changed.
    case keyChanged
    /// Whisper message revealed on long press.
    case whisperReveal
    /// Time capsule unlocked.
    case capsuleUnlock
    /// App or conversation locked.
    case lock
}
