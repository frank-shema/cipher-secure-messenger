import CipherNetworking
import Testing

struct CipherNetworkingTests {
    @Test func moduleNameMatchesTargetName() {
        #expect(CipherNetworking.moduleName == "CipherNetworking")
    }
}
