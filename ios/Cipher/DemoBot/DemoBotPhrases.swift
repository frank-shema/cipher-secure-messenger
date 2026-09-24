#if DEBUG
import CipherCore
import Foundation

/// Everything Echo says, in one place, so its voice stays consistent and every line is translatable.
/// Keys live under `demo.echo.*` in the app's String Catalog.
enum DemoBotPhrases {
    static var greeting: String {
        String(
            localized: "demo.echo.greeting",
            defaultValue: """
            Hi, I'm Echo 👋 I'm a second Cipher client living inside this very app, with my own identity keys \
            in a separate Keychain slot and my own message store. Everything between us is sealed end-to-end; \
            the relay only ever sees ciphertext. Say “help” to see what I can do.
            """
        )
    }

    static var greetingAgain: String {
        String(localized: "demo.echo.greeting.again", defaultValue: "Hey again 👋 Still here, still encrypted. Say “help” for the menu.")
    }

    static var helpHint: String {
        String(localized: "demo.echo.help.hint", defaultValue: "Say “help” and I'll list what I can do.")
    }

    static func help(capsuleSeconds: Int) -> String {
        String(
            localized: "demo.echo.help",
            defaultValue: """
            Here's what I understand:
            • help — this list
            • photo — a view-once picture I draw on this device
            • capsule — a Time Capsule that unlocks \(capsuleSeconds) seconds later
            • whisper — a message you hold to reveal
            • disappear — this chat's disappearing setting
            • ping — pong
            Reply to one of my messages and I'll quote you back. Add a ! and I'll react.
            """
        )
    }

    static var pong: String {
        String(localized: "demo.echo.pong", defaultValue: "pong 🏓 Sealed, signed and decrypted without leaving this device.")
    }

    static var photoCaption: String {
        String(
            localized: "demo.echo.photo.caption",
            defaultValue: "Drawn just now with CoreGraphics, no metadata, encrypted before upload. View once — then it's gone."
        )
    }

    static func capsule(sealedAt: Date, seconds: Int) -> String {
        let time = sealedAt.formatted(date: .omitted, time: .standard)
        return String(
            localized: "demo.echo.capsule",
            defaultValue: "Sealed at \(time). This capsule unlocks \(seconds) seconds later; patience is a feature."
        )
    }

    static var whisper: String {
        String(localized: "demo.echo.whisper", defaultValue: "psst… this one's a whisper. Hold to read it; let go and it blurs again.")
    }

    static func disappearing(timer: TimeInterval?) -> String {
        guard let timer, timer > 0 else {
            return String(
                localized: "demo.echo.disappearing.off",
                defaultValue: """
                Disappearing messages are off in this chat. Turn them on from the header menu and I'll follow the same timer.
                """
            )
        }
        let duration = Duration.seconds(timer).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return String(
            localized: "demo.echo.disappearing.on",
            defaultValue: "Messages here disappear \(duration) after they're read. Mine follow the same timer."
        )
    }

    static func receivedAttachment(_ attachment: Attachment) -> String {
        let kind = attachment.mimeType.hasPrefix("image/")
            ? String(localized: "demo.echo.attachment.kind.photo", defaultValue: "photo")
            : String(localized: "demo.echo.attachment.kind.file", defaultValue: "file")
        let size = Int64(attachment.size).formatted(.byteCount(style: .file))
        return String(
            localized: "demo.echo.attachment.received",
            defaultValue: "Got your \(kind) (\(size)). The key came inside the ciphertext, so I decrypted it right here."
        )
    }

    static var tampered: String {
        String(
            localized: "demo.echo.tampered",
            defaultValue: """
            Something arrived from you that failed verification, so I didn't read it. If you sent something, try again.
            """
        )
    }

    static func system(_ kind: SystemEvent.Kind) -> String? {
        switch kind {
        case .disappearingChanged:
            String(
                localized: "demo.echo.system.disappearingChanged",
                defaultValue: "Noticed you changed the disappearing timer. I'll match whatever your next message uses."
            )
        case .keyVerified:
            String(
                localized: "demo.echo.system.keyVerified",
                defaultValue: "You verified my keys — now it's mutual, as far as I'm concerned. 🔐"
            )
        case .screenshotTaken:
            String(localized: "demo.echo.system.screenshot", defaultValue: "A screenshot? I saw that. 👀")
        case .viewOnceOpened:
            nil
        }
    }

    static func reversedWords(_ text: String) -> String {
        String(localized: "demo.echo.twist.reversedWords", defaultValue: "\(text) — your words, mirrored.")
    }

    static func mirrored(_ text: String) -> String {
        String(localized: "demo.echo.twist.mirrored", defaultValue: "\(text) 🪞")
    }

    static func questioned(_ text: String) -> String {
        String(localized: "demo.echo.twist.questioned", defaultValue: "“\(text)?” Only you and I can read that, so answer freely.")
    }

    static func counted(words: Int, characters: Int) -> String {
        String(
            localized: "demo.echo.twist.counted",
            defaultValue: "\(words) words, \(characters) characters, one envelope. The relay saw none of them."
        )
    }
}
#endif
