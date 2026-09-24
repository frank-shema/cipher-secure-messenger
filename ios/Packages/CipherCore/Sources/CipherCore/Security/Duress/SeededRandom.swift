import Foundation

/// SplitMix64: a tiny, fast generator with a full 64-bit state. Chosen because the decoy inbox must
/// be identical on every launch for the same seed (a decoy that reshuffles itself is a tell), and the
/// system generator is deliberately unseedable.
struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A version-4-shaped UUID from generator output, so decoy ids look exactly like real ones.
    mutating func uuid() -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let high = next()
        let low = next()
        for offset in 0..<8 {
            bytes[offset] = UInt8(truncatingIfNeeded: high >> (offset * 8))
            bytes[offset + 8] = UInt8(truncatingIfNeeded: low >> (offset * 8))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    mutating func data(count: Int) -> Data {
        var bytes = Data(capacity: count)
        while bytes.count < count {
            var word = next()
            for _ in 0..<8 where bytes.count < count {
                bytes.append(UInt8(truncatingIfNeeded: word))
                word >>= 8
            }
        }
        return bytes
    }

    mutating func seconds(between lower: TimeInterval, and upper: TimeInterval) -> TimeInterval {
        TimeInterval.random(in: min(lower, upper)...max(lower, upper), using: &self)
    }

    mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < probability
    }
}
