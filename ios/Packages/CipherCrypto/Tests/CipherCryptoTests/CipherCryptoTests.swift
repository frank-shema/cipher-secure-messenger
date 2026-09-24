import CipherCrypto
import Testing

struct CipherCryptoTests {
    @Test func moduleNameMatchesTargetName() {
        #expect(CipherCrypto.moduleName == "CipherCrypto")
    }
}
