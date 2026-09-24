import Foundation
import Security

/// Failures of the Keychain wrapper, kept typed so callers can distinguish "nothing stored" from a
/// real Security framework failure and show a meaningful message instead of a raw `OSStatus`.
enum KeychainError: Error, LocalizedError, Hashable, Sendable {
    case unexpectedStatus(OSStatus)
    case unexpectedItemShape

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            String(localized: "error.keychain.status", defaultValue: "The secure store reported an error.")
                + " (\(status))"
        case .unexpectedItemShape:
            String(localized: "error.keychain.shape", defaultValue: "The secure store returned unexpected data.")
        }
    }
}

/// When an item may be read, always `ThisDeviceOnly` so no secret migrates to another device in a backup.
enum KeychainAccessibility: Sendable {
    /// Only while the device is unlocked: for secrets the person uses interactively (PIN material).
    case whenUnlocked
    /// From the first unlock after boot until the next restart: for session tokens, which the app
    /// must read while restoring a session in the background or right after a reboot.
    case afterFirstUnlock

    var attribute: CFString {
        switch self {
        case .whenUnlocked: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

/// Thin, synchronous wrapper over `SecItem*` for generic-password items.
///
/// Every item is scoped to one `service` and carries the store's `accessibility`; a write re-applies it,
/// so an item created under an older policy is migrated the next time it is saved.
/// `kSecUseDataProtectionKeychain` opts into the modern keychain on every platform so behaviour is
/// identical on simulator, device and Catalyst.
struct KeychainStore: Sendable {
    let service: String
    var accessibility: KeychainAccessibility = .whenUnlocked

    func read(account: String) throws(KeychainError) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedItemShape }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Upserts: an existing item is updated in place, accessibility included, so every item under this
    /// service ends up with the same policy regardless of which version of the app created it.
    func write(_ data: Data, account: String) throws(KeychainError) {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.attribute
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = accessibility.attribute
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    /// Idempotent: deleting something that is not there is a success, which keeps sign-out safe to repeat.
    func delete(account: String) throws(KeychainError) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any
        ]
    }
}
