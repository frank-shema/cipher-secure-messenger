import Testing
@testable import CipherCore

@Test func disappearingTimerOffNeverExpires() {
    #expect(!DisappearingTimer.off.isExpired(readAt: .distantPast, now: .distantFuture))
}
