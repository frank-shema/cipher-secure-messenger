import CipherCore
import Testing

struct CipherAppTests {
    @Test func appTargetsCoreProtocolVersionOne() {
        #expect(CipherCore.protocolVersion == 1)
    }
}
