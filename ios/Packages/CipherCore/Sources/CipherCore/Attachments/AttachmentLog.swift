import Foundation
import os

extension CoreLog {
    /// Attachment sealing, upload and download. Logs ids, byte counts and phases only: never a
    /// filename, MIME type, key or digest, all of which are content the relay must not learn either.
    static let attachments = Logger(subsystem: "com.cipher.core", category: "attachments")
}
