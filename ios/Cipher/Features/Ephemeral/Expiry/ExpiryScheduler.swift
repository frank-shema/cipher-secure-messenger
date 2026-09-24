import CipherCore
import Foundation

/// Runs the expiry sweep on a cadence and tells subscribers which messages were deleted.
///
/// Ticks every 5 s while any chat is on screen, because a countdown ring that hits zero should be
/// followed by the bubble leaving within a breath; every 60 s otherwise, which is enough to keep
/// the inbox honest without waking the process constantly. The scheduler is background-safe in the
/// only way iOS allows: it stops ticking when the app leaves the foreground (a suspended process
/// cannot run anyway) and sweeps immediately on return, so anything that expired while suspended
/// is gone before the first frame that could show it. Expired rows are never visible in between
/// either, since `MessageVisibilityPolicy` already reports them as consumed.
actor ExpiryScheduler {
    /// How often the sweep runs.
    enum Cadence: Hashable, Sendable {
        case chatVisible
        case idle
        case paused
    }

    private let deleter: any ExpiredMessageDeleting
    private let clock: any Clock
    private let chatInterval: Duration
    private let idleInterval: Duration
    private var subscribers: [UUID: AsyncStream<[MessageID]>.Continuation] = [:]
    private var visibleChats: Set<ConversationID> = []
    private var loop: Task<Void, Never>?
    private var isRunning = false
    private var isInBackground = false
    private(set) var cadence: Cadence = .paused
    private(set) var lastSweepAt: Date?

    init(
        deleter: any ExpiredMessageDeleting,
        clock: any Clock = SystemClock(),
        chatInterval: Duration = .seconds(5),
        idleInterval: Duration = .seconds(60)
    ) {
        self.deleter = deleter
        self.clock = clock
        self.chatInterval = chatInterval
        self.idleInterval = idleInterval
    }

    /// Ids deleted by each sweep, one array per sweep that removed something. Each access creates
    /// an independent subscription; it ends when the consumer's task is cancelled.
    var deletions: AsyncStream<[MessageID]> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<[MessageID]>.makeStream(bufferingPolicy: .bufferingNewest(8))
        subscribers[key] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(key) }
        }
        return stream
    }

    // MARK: Lifecycle

    /// Starts idle ticking and sweeps once right away, so launch never shows stale rows.
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        await sweep()
        restartLoop()
    }

    func stop() {
        isRunning = false
        loop?.cancel()
        loop = nil
        cadence = .paused
        for continuation in subscribers.values { continuation.finish() }
        subscribers.removeAll()
    }

    func chatDidAppear(_ conversationId: ConversationID) async {
        let wasEmpty = visibleChats.isEmpty
        visibleChats.insert(conversationId)
        guard wasEmpty else { return }
        await sweep()
        restartLoop()
    }

    func chatDidDisappear(_ conversationId: ConversationID) {
        visibleChats.remove(conversationId)
        if visibleChats.isEmpty { restartLoop() }
    }

    func applicationDidEnterBackground() {
        isInBackground = true
        loop?.cancel()
        loop = nil
        cadence = .paused
    }

    func applicationDidBecomeActive() async {
        isInBackground = false
        guard isRunning else { return }
        await sweep()
        restartLoop()
    }

    // MARK: Sweeping

    /// Deletes everything expired as of the injected clock and publishes the ids. Failures are
    /// logged and swallowed: the next tick retries, and an unreadable store must not stop the UI.
    @discardableResult
    func sweep() async -> [MessageID] {
        let now = clock.now()
        lastSweepAt = now
        do {
            let deleted = try await deleter.deleteExpired(now: now)
            guard !deleted.isEmpty else { return [] }
            EphemeralLog.expiry.notice("swept \(deleted.count, privacy: .public) expired messages")
            for continuation in subscribers.values { continuation.yield(deleted) }
            return deleted
        } catch {
            let failure = String(describing: type(of: error))
            EphemeralLog.expiry.error("sweep failed: \(failure, privacy: .public)")
            return []
        }
    }

    private func restartLoop() {
        loop?.cancel()
        loop = nil
        guard isRunning, !isInBackground else {
            cadence = .paused
            return
        }
        cadence = visibleChats.isEmpty ? .idle : .chatVisible
        let interval = visibleChats.isEmpty ? idleInterval : chatInterval
        loop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval, clock: .continuous)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                await self.sweep()
            }
        }
    }

    private func removeSubscriber(_ key: UUID) {
        subscribers.removeValue(forKey: key)
    }
}
