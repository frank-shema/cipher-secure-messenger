import CipherPersistence
import Testing

struct CipherPersistenceTests {
    @Test func moduleNameMatchesTargetName() {
        #expect(CipherPersistence.moduleName == "CipherPersistence")
    }
}
