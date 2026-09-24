import Foundation

/// Holds this device's long-term Curve25519 private keys. Core only ever sees the public halves:
/// every operation that needs a private key lives behind `MessageCryptoService`, whose implementation
/// reads the store directly. This keeps key material out of the domain layer entirely.
public protocol IdentityKeyStore: Sendable {
    func hasIdentity() async throws -> Bool
    /// Generates a fresh identity. Implementations must refuse to overwrite an existing one, so a bug
    /// can never silently destroy the keys every conversation is pinned to; rotation deletes first.
    func createIdentity() async throws -> PublicKeyBundleUpload
    func publicKeys() async throws -> PublicKeyBundleUpload
    func deleteIdentity() async throws
}
