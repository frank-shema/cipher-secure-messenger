import Foundation

/// Turns keystrokes into at most one `typing.start` and one `typing.stop` per burst of typing.
/// The first keystroke starts, every keystroke pushes the idle deadline, and a send or three idle
/// seconds stops. Keeping this off the ViewModel makes the timing rules a single, readable place.
@MainActor
final class TypingDebouncer {
    private let idleInterval: TimeInterval
    private let onChange: @MainActor (Bool) -> Void
    private var idleTask: Task<Void, Never>?
    private(set) var isTyping = false

    init(idleInterval: TimeInterval = 3, onChange: @escaping @MainActor (Bool) -> Void) {
        self.idleInterval = idleInterval
        self.onChange = onChange
    }

    /// Call on every draft edit. An empty draft counts as a stop: deleting everything you typed
    /// should not leave the other side staring at a bouncing indicator.
    func draftChanged(isEmpty: Bool) {
        if isEmpty {
            stop()
            return
        }
        if !isTyping {
            isTyping = true
            onChange(true)
        }
        scheduleIdleStop()
    }

    /// Call after a send and when leaving the screen.
    func stop() {
        idleTask?.cancel()
        idleTask = nil
        guard isTyping else { return }
        isTyping = false
        onChange(false)
    }

    private func scheduleIdleStop() {
        idleTask?.cancel()
        let interval = idleInterval
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }
}
