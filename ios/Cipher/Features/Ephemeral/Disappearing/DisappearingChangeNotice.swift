import CipherCore
import Foundation

/// Wording for the `disappearing_changed` system row. The notice's flags say what the timer became,
/// so the transcript can read "Bob set messages to disappear after 5 minutes" instead of the
/// generic "timer changed" the kind alone allows.
enum DisappearingChangeNotice {
    static func text(for message: Message, contactName: String) -> String {
        let timer = DisappearingTimer(seconds: message.flags.disappearAfter)
        switch (message.direction, timer.isEnabled) {
        case (.outgoing, true):
            return String(localized: "disappearing.notice.you.on",
                          defaultValue: "You set messages to disappear \(timer.sentenceFragment)")
        case (.outgoing, false):
            return String(localized: "disappearing.notice.you.off", defaultValue: "You turned off disappearing messages")
        case (.incoming, true):
            return String(localized: "disappearing.notice.them.on",
                          defaultValue: "\(contactName) set messages to disappear \(timer.sentenceFragment)")
        case (.incoming, false):
            return String(localized: "disappearing.notice.them.off",
                          defaultValue: "\(contactName) turned off disappearing messages")
        }
    }

    /// Whether `message` is a timer notice, for row renderers choosing this wording.
    static func isTimerNotice(_ message: Message) -> Bool {
        if case .system(let event) = message.content { return event.kind == .disappearingChanged }
        return false
    }
}
