import CipherDesign
import SwiftUI
import Testing

struct MotionSecurityTests {
    @Test func decryptScheduleIsDeterministicAndMonotonic() {
        let first = DecryptSchedule(count: 24, duration: 0.4)
        let second = DecryptSchedule(count: 24, duration: 0.4)
        #expect(first == second)
        let starts = (0..<24).map(first.start(of:))
        #expect(zip(starts, starts.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(first.resolveTime(of: 23) <= first.duration + 1e-9)
        #expect(first.state(of: 0, at: 0) == .resolving)
        #expect(first.state(of: 23, at: first.totalDuration) == .plain)
        #expect(CipherGlyphs.glyph(index: 3, frame: 7) == CipherGlyphs.glyph(index: 3, frame: 7))
    }

    @Test func trustRingTierThresholds() {
        #expect(TrustRing<EmptyView>.tier(for: 0) == .low)
        #expect(TrustRing<EmptyView>.tier(for: 0.39) == .low)
        #expect(TrustRing<EmptyView>.tier(for: 0.4) == .medium)
        #expect(TrustRing<EmptyView>.tier(for: 0.74) == .medium)
        #expect(TrustRing<EmptyView>.tier(for: 0.75) == .high)
        #expect(TrustRing<EmptyView>.tier(for: 1) == .high)
    }

    @Test func countdownRingClamps() {
        #expect(CountdownRing.clamp(-0.5) == 0)
        #expect(CountdownRing.clamp(1.7) == 1)
        #expect(CountdownRing.clamp(.nan) == 0)
        #expect(CountdownRing.clamp(0.42) == 0.42)
        #expect(CountdownRing.label(forRemaining: 59) == "59s")
        #expect(CountdownRing.label(forRemaining: 3600) == "1h")
    }
}
