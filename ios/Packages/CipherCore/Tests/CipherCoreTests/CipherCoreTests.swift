import CipherCore
import Testing

struct CipherCoreTests {
    @Test func protocolVersionIsPinnedToOne() {
        #expect(CipherCore.protocolVersion == 1)
    }
}
