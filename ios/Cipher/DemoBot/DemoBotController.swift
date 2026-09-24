#if DEBUG
import CipherCore
import Foundation
import Observation

/// Ties Echo to the app: runs it while a person is signed in and the "Demo companion (Echo)" switch is
/// on, stops it otherwise, and makes sure the person has a conversation with Echo to type into.
///
/// The switch is a plain `UserDefaults` flag (`AppPreferences.Key.demoCompanionEnabled`) written by
/// Settings; the controller registers `true` as its default so Echo is on out of the box, and watches
/// the defaults so a toggle takes effect without restarting the app.
@MainActor
@Observable
final class DemoBotController {
    typealias ConversationStarter = @Sendable (_ username: String) async throws -> Conversation

    private(set) var status: DemoBot.Status = .stopped
    /// The signed-in person's conversation with Echo, once it exists on both sides.
    private(set) var conversationId: ConversationID?
    /// Why the conversation could not be created although Echo itself is fine.
    private(set) var conversationProblem: String?

    @ObservationIgnored private let bot: DemoBot
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let credentials: DemoBotCredentials
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var starter: ConversationStarter?
    @ObservationIgnored private var desiredRunning = false
    @ObservationIgnored private var lifecycle: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var preferenceTask: Task<Void, Never>?

    init(configuration: DemoBotConfiguration, defaults: UserDefaults = .standard) {
        defaults.register(defaults: [AppPreferences.Key.demoCompanionEnabled: true])
        self.defaults = defaults
        self.credentials = configuration.credentials
        self.bot = DemoBot(configuration: configuration, memory: DemoBotMemory(defaults: defaults))
        observeStatus()
        observePreference()
    }

    deinit {
        lifecycle?.cancel()
        statusTask?.cancel()
        preferenceTask?.cancel()
    }

    var username: String {
        credentials.username
    }

    /// The Settings switch. Reading goes through `AppPreferences` so Settings and the controller can
    /// never disagree about where the flag lives.
    var isEnabled: Bool {
        get { AppPreferences.isDemoCompanionEnabled(in: defaults) }
        set {
            AppPreferences.setDemoCompanionEnabled(newValue, in: defaults)
            reconcile()
        }
    }

    // MARK: - Session hooks

    /// Call from `AppSession.onAuthenticated`. `startConversation` is the person's own
    /// `StartConversationUseCase`, so the conversation is created with the person's keys pinned to
    /// Echo's identity exactly as it would be for any other contact.
    func sessionDidBecomeReady(_ session: Session, startConversation: @escaping ConversationStarter) {
        guard session.user.username != credentials.username else {
            DemoBotLog.bot.notice("signed in as the companion account itself; Echo stays off")
            return
        }
        self.session = session
        self.starter = startConversation
        reconcile()
    }

    /// Call from `AppSession.onSignedOut`.
    func sessionDidEnd() {
        session = nil
        starter = nil
        reconcile()
    }

    // MARK: - Reconciliation

    /// Serialises start/stop so a quick toggle off-on-off cannot leave two bots or none.
    private func reconcile() {
        let shouldRun = isEnabled && session != nil
        guard shouldRun != desiredRunning else { return }
        desiredRunning = shouldRun
        let previous = lifecycle
        lifecycle = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            if shouldRun {
                await bringUp()
            } else {
                await tearDown()
            }
        }
    }

    private func bringUp() async {
        guard let starter else { return }
        do {
            try await bot.start()
            guard desiredRunning else { return }
            let conversation = try await starter(credentials.username)
            guard desiredRunning else { return }
            conversationId = conversation.id
            conversationProblem = nil
            DemoBotLog.bot.info("conversation with Echo ready: \(conversation.id.description, privacy: .public)")
        } catch let error as DemoBotError {
            DemoBotLog.bot.error("Echo unavailable: \(String(describing: error), privacy: .public)")
        } catch {
            conversationProblem = PresentableProblem(error: error).detail
            DemoBotLog.bot.error("conversation with Echo failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func tearDown() async {
        await bot.stop()
        conversationId = nil
        conversationProblem = nil
    }

    // MARK: - Observation

    private func observeStatus() {
        statusTask = Task { [weak self, bot] in
            for await status in await bot.statusUpdates {
                guard let self else { return }
                self.status = status
            }
        }
    }

    /// `UserDefaults.didChangeNotification` fires for every default, so `reconcile()` compares desired
    /// and current state and does nothing when the switch has not moved.
    private func observePreference() {
        preferenceTask = Task.detached { [weak self] in
            let changes = NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification)
            for await _ in changes {
                guard let self else { return }
                await self.reconcile()
            }
        }
    }
}
#endif
