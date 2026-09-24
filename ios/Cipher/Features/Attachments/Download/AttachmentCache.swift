import CipherCore
import Foundation

enum AttachmentCacheError: Error, LocalizedError, Hashable, Sendable {
    case directoryUnavailable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            String(localized: "attachments.error.cacheUnavailable", defaultValue: "Attachments cannot be stored on this device right now.")
        case .writeFailed:
            String(localized: "attachments.error.cacheWrite", defaultValue: "The attachment could not be saved.")
        }
    }
}

/// Decrypted attachments on disk, per account, under complete file protection: the files are
/// unreadable while the device is locked, and switching accounts never exposes another account's
/// downloads. The directory sits in Caches so the system may evict it; every file can be re-fetched.
struct AttachmentCache: Sendable {
    let root: URL

    init(accountId: UserID) throws(AttachmentCacheError) {
        let manager = FileManager.default
        guard let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw .directoryUnavailable
        }
        root = caches.appending(path: "Cipher/\(accountId.description)/attachments", directoryHint: .isDirectory)
        do {
            try manager.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } catch {
            throw .directoryUnavailable
        }
    }

    /// The cached plaintext for a message, if it has been downloaded before.
    func existingFile(for messageId: MessageID) -> URL? {
        let folder = folder(for: messageId)
        let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return contents?.first
    }

    /// Writes atomically with `.completeFileProtection`; the folder attribute alone would not cover a
    /// file created through a temporary name.
    @discardableResult
    func store(_ data: Data, messageId: MessageID, filename: String) throws(AttachmentCacheError) -> URL {
        let folder = folder(for: messageId)
        let url = folder.appending(path: Self.sanitized(filename), directoryHint: .notDirectory)
        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw .writeFailed
        }
        return url
    }

    func remove(messageId: MessageID) {
        try? FileManager.default.removeItem(at: folder(for: messageId))
    }

    /// Sign-out hook: nothing of this account's may outlive the session on disk.
    func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }

    private func folder(for messageId: MessageID) -> URL {
        root.appending(path: messageId.description, directoryHint: .isDirectory)
    }

    /// The sender chose the name, so it is untrusted: path separators, control characters and hidden
    /// prefixes are stripped and an empty result falls back to a neutral name.
    static func sanitized(_ filename: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:").union(.controlCharacters).union(.newlines)
        let cleaned = filename.unicodeScalars.filter { !forbidden.contains($0) }
        var name = String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespaces)
        while name.hasPrefix(".") { name.removeFirst() }
        return name.isEmpty ? "attachment" : String(name.prefix(120))
    }
}
