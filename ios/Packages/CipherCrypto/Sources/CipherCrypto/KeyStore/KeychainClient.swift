import Foundation
import Security

/// Thin, typed wrapper over `SecItem*` for generic-password items. All items are created with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (never migrated to another device via backup, and
/// unreadable while locked) and `kSecUseDataProtectionKeychain` (the modern, per-app-sandboxed
/// keychain on every platform, so behaviour is identical on macOS and iOS).
struct KeychainClient: Sendable {
    let service: String

    /// Returns `nil` when no item exists; every other failure is a typed error.
    func read(account: String) throws(KeyStoreError) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw .corruptIdentity }
            return data
        case errSecItemNotFound:
            return nil
        default:
            CryptoLog.keyStore.error("Keychain read failed: \(Self.describe(status), privacy: .public)")
            throw KeyStoreError.fromStatus(status)
        }
    }

    /// Adds a new item and refuses to overwrite an existing one (`errSecDuplicateItem` surfaces as
    /// `.identityAlreadyExists`), which is the property the identity store's contract depends on.
    func add(account: String, data: Data) throws(KeyStoreError) {
        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            CryptoLog.keyStore.error("Keychain add failed: \(Self.describe(status), privacy: .public)")
            throw KeyStoreError.fromStatus(status)
        }
    }

    /// Idempotent: a missing item is not an error, so deleting twice (or after a partial write) is safe.
    func delete(account: String) throws(KeyStoreError) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            CryptoLog.keyStore.error("Keychain delete failed: \(Self.describe(status), privacy: .public)")
            throw KeyStoreError.fromStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false
        ]
    }

    private static func describe(_ status: OSStatus) -> String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "\(status) (\(message))"
    }
}
