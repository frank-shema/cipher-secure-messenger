import Observation
import SwiftUI

/// Visual style for a toast.
public enum ToastStyle: Sendable, Hashable {
    case info, success, warning, error
}

/// A transient message shown by `ToastCenter`.
public struct Toast: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let message: String
    public let style: ToastStyle
    public let systemImage: String?
    /// Seconds before auto-dismiss.
    public let duration: Duration

    /// Creates a toast.
    public init(
        _ message: String,
        style: ToastStyle = .info,
        systemImage: String? = nil,
        duration: Duration = .seconds(2.5)
    ) {
        self.id = UUID()
        self.message = message
        self.style = style
        self.systemImage = systemImage
        self.duration = duration
    }
}

/// Queues toasts and presents them one at a time with auto-dismiss.
/// Inject via `.environment(toastCenter)` and render with `.toastHost()`.
@MainActor
@Observable
public final class ToastCenter {
    /// The toast currently on screen, if any.
    public private(set) var current: Toast?
    private var queue: [Toast] = []
    private var dismissTask: Task<Void, Never>?

    /// Creates an empty center.
    public init() {}

    /// Enqueues `toast`; it shows immediately if nothing is visible.
    public func show(_ toast: Toast) {
        queue.append(toast)
        if current == nil { advance() }
    }

    /// Convenience for `show(Toast(...))`.
    public func show(_ message: String, style: ToastStyle = .info, systemImage: String? = nil) {
        show(Toast(message, style: style, systemImage: systemImage))
    }

    /// Dismisses the current toast and shows the next queued one.
    public func dismissCurrent() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
        advance()
    }

    private func advance() {
        guard current == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        current = next
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: next.duration)
            guard !Task.isCancelled, let self, self.current?.id == next.id else { return }
            self.current = nil
            self.advance()
        }
    }
}
