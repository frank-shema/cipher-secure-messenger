import CipherCore
import Foundation

extension DisappearingTimer {
    /// Menu label. Keys mirror Core's `titleKey` (`disappearing.timer.<case>`) but are spelled out
    /// as literals here because the string catalog needs a static key to extract.
    var title: String {
        switch self {
        case .off:
            String(localized: "disappearing.timer.off", defaultValue: "Off")
        case .thirtySeconds:
            String(localized: "disappearing.timer.thirtySeconds", defaultValue: "30 seconds")
        case .fiveMinutes:
            String(localized: "disappearing.timer.fiveMinutes", defaultValue: "5 minutes")
        case .oneHour:
            String(localized: "disappearing.timer.oneHour", defaultValue: "1 hour")
        case .oneDay:
            String(localized: "disappearing.timer.oneDay", defaultValue: "1 day")
        }
    }

    /// Short badge form for headers and rows ("30s", "5m", "1h", "1d"); empty when off.
    var badge: String {
        switch self {
        case .off: ""
        case .thirtySeconds: "30s"
        case .fiveMinutes: "5m"
        case .oneHour: "1h"
        case .oneDay: "1d"
        }
    }

    /// SF Symbol for the state: a timer once enabled, a slashed one when off.
    var systemImage: String {
        isEnabled ? "timer" : "timer.slash"
    }

    /// How the timer reads in a sentence ("after 5 minutes"); used by the change notice.
    var sentenceFragment: String {
        switch self {
        case .off:
            String(localized: "disappearing.timer.fragment.off", defaultValue: "off")
        case .thirtySeconds:
            String(localized: "disappearing.timer.fragment.thirtySeconds", defaultValue: "after 30 seconds")
        case .fiveMinutes:
            String(localized: "disappearing.timer.fragment.fiveMinutes", defaultValue: "after 5 minutes")
        case .oneHour:
            String(localized: "disappearing.timer.fragment.oneHour", defaultValue: "after 1 hour")
        case .oneDay:
            String(localized: "disappearing.timer.fragment.oneDay", defaultValue: "after 1 day")
        }
    }
}
