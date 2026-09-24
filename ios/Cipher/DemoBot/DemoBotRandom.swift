#if DEBUG
import CipherCore
import Foundation

/// SplitMix64: a tiny, seedable generator so Echo's "twists" and pictures are reproducible per
/// message (same message id, same picture) without pulling the system generator into a
/// deterministic path. Not cryptographic and never used for anything that must be.
struct DemoBotRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// The first eight bytes of a message id, so a seed is stable across relaunches and devices.
    static func seed(for messageId: MessageID) -> UInt64 {
        var bytes = messageId.uuid.uuid
        return withUnsafeBytes(of: &bytes) { $0.loadUnaligned(as: UInt64.self) }
    }
}
#endif
