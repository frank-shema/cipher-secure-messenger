import os

/// Loggers for the attachments feature. Only ids, byte counts, dimensions and phases are ever
/// interpolated: never a filename, MIME type, key, digest or anything read out of a photo.
enum AttachmentsLog {
    private static let subsystem = "com.cipher.app"

    static let composer = Logger(subsystem: subsystem, category: "attachments.composer")
    static let processing = Logger(subsystem: subsystem, category: "attachments.processing")
    static let transfer = Logger(subsystem: subsystem, category: "attachments.transfer")
    static let viewer = Logger(subsystem: subsystem, category: "attachments.viewer")
    static let viewOnce = Logger(subsystem: subsystem, category: "attachments.viewonce")
}
