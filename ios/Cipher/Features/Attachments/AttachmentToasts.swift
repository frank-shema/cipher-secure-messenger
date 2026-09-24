import CipherDesign
import Foundation

/// Every transient notice the attachments feature shows, in one place so the wording stays
/// consistent and translators see them together.
enum AttachmentToasts {
    /// Shown when a picked photo carried GPS data that was stripped before sealing.
    static var locationRemoved: Toast {
        Toast(
            String(localized: "attachments.toast.locationRemoved", defaultValue: "📍 Location removed from photo"),
            style: .success,
            systemImage: "location.slash.fill"
        )
    }

    /// Shown when EXIF, TIFF or maker-note data was stripped but the photo had no GPS fix.
    static var metadataRemoved: Toast {
        Toast(
            String(localized: "attachments.toast.metadataRemoved", defaultValue: "Camera details removed from photo"),
            style: .info,
            systemImage: "camera.metering.none"
        )
    }

    static var screenshotReported: Toast {
        Toast(
            String(localized: "attachments.toast.screenshotReported", defaultValue: "Screenshot reported to the sender"),
            style: .warning,
            systemImage: "camera.viewfinder",
            duration: .seconds(3.5)
        )
    }

    static var viewOnceDeleted: Toast {
        Toast(
            String(localized: "attachments.toast.viewOnceDeleted", defaultValue: "View-once photo deleted from this device"),
            style: .info,
            systemImage: "eye.slash.fill"
        )
    }

    static var fileTooLarge: Toast {
        Toast(
            String(localized: "attachments.toast.tooLarge", defaultValue: "That file is over the 25 MB limit"),
            style: .error,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    static func preparingFailed(_ reason: String) -> Toast {
        Toast(reason, style: .error, systemImage: "xmark.octagon.fill", duration: .seconds(4))
    }
}
