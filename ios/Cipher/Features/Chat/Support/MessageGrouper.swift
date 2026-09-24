import CipherCore
import Foundation

/// One message placed inside a sender run, with the position flags the bubble needs to pick its
/// tail and spacing.
struct GroupedMessage: Identifiable, Hashable, Sendable {
    var message: Message
    var isFirstInGroup: Bool
    var isLastInGroup: Bool

    var id: MessageID { message.id }
}

/// Consecutive messages from the same sender within `MessageGrouper.runWindow`.
struct MessageGroup: Identifiable, Hashable, Sendable {
    var id: MessageID
    var direction: MessageDirection
    var items: [GroupedMessage]
}

/// All groups that fall on one calendar day, headed by a `DaySeparator`.
struct MessageDaySection: Identifiable, Hashable, Sendable {
    var id: Date
    var groups: [MessageGroup]

    var date: Date { id }
}

/// Pure layout maths for the message list: sorts, drops payloads that render on other rows, and
/// splits the rest into day sections and sender runs. It is `nonisolated` on purpose so the
/// ViewModel can run it on the cooperative pool for long histories.
enum MessageGrouper {
    /// Two messages from the same sender closer than this belong to one run and share a tail.
    static let runWindow: TimeInterval = 3 * 60

    static func sections(
        from messages: [Message],
        calendar: Calendar = .current
    ) -> [MessageDaySection] {
        let visible = messages
            .filter { !$0.content.isReaction }
            .sorted { $0.effectiveTimestamp < $1.effectiveTimestamp }

        var sections: [MessageDaySection] = []
        var currentDay: Date?
        var groups: [MessageGroup] = []
        var run: [Message] = []

        func flushRun() {
            guard let first = run.first else { return }
            let items = run.enumerated().map { offset, message in
                GroupedMessage(
                    message: message,
                    isFirstInGroup: offset == 0,
                    isLastInGroup: offset == run.count - 1
                )
            }
            groups.append(MessageGroup(id: first.id, direction: first.direction, items: items))
            run.removeAll()
        }

        func flushDay() {
            flushRun()
            if let currentDay, !groups.isEmpty {
                sections.append(MessageDaySection(id: currentDay, groups: groups))
            }
            groups.removeAll()
        }

        for message in visible {
            let day = calendar.startOfDay(for: message.effectiveTimestamp)
            if day != currentDay {
                flushDay()
                currentDay = day
            }
            if let previous = run.last, !continuesRun(previous, message) {
                flushRun()
            }
            run.append(message)
        }
        flushDay()
        return sections
    }

    /// System events always stand alone; everything else runs together when the sender and the
    /// time window agree.
    static func continuesRun(_ previous: Message, _ next: Message) -> Bool {
        guard previous.senderId == next.senderId else { return false }
        if case .system = previous.content { return false }
        if case .system = next.content { return false }
        return next.effectiveTimestamp.timeIntervalSince(previous.effectiveTimestamp) < runWindow
    }
}
