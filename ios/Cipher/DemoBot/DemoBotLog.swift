#if DEBUG
import os

/// Loggers for the demo companion. Categories are prefixed `demo.` so a Console filter on the app's
/// subsystem can include or exclude the bot in one step. Like the rest of the app it never logs
/// plaintext, key material, tokens or ciphertext: identifiers, counts and phases only.
enum DemoBotLog {
    private static let subsystem = "com.cipher.app"

    static let bot = Logger(subsystem: subsystem, category: "demo.bot")
    static let account = Logger(subsystem: subsystem, category: "demo.account")
    static let reply = Logger(subsystem: subsystem, category: "demo.reply")
    static let image = Logger(subsystem: subsystem, category: "demo.image")
    static let selfTest = Logger(subsystem: subsystem, category: "demo.selftest")
}
#endif
