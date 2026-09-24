import Foundation

/// Read access to the privacy preferences the trust score depends on. Lives here rather than in
/// `Ports` because it is a presentation-level toggle (UserDefaults in the app) and not relay state.
public protocol PrivacyPreferencesReader: Sendable {
    /// Whether attachments are stripped of EXIF, GPS and similar metadata before encryption.
    func isMetadataStrippingEnabled() async -> Bool
}

/// Preferences with a fixed answer, for previews and for builds where the toggle does not exist.
public struct StaticPrivacyPreferences: PrivacyPreferencesReader {
    public var metadataStrippingEnabled: Bool

    public init(metadataStrippingEnabled: Bool) {
        self.metadataStrippingEnabled = metadataStrippingEnabled
    }

    public func isMetadataStrippingEnabled() async -> Bool {
        metadataStrippingEnabled
    }
}

/// Gathers the signals for one conversation and scores them. Logs the level and percentage only:
/// the contact identity is a relay-visible id, but there is no reason to write it next to a verdict.
public struct EvaluateTrustUseCase: Sendable {
    private let conversations: any ConversationRepository
    private let preferences: any PrivacyPreferencesReader
    private let clock: any Clock
    private let evaluator: TrustEvaluator

    public init(
        conversations: any ConversationRepository,
        preferences: any PrivacyPreferencesReader,
        clock: any Clock = SystemClock(),
        evaluator: TrustEvaluator = TrustEvaluator()
    ) {
        self.conversations = conversations
        self.preferences = preferences
        self.clock = clock
        self.evaluator = evaluator
    }

    public func execute(conversationId: ConversationID) async throws -> TrustReport {
        guard let conversation = try await conversations.fetch(id: conversationId) else {
            throw CipherCoreError.conversationNotFound(conversationId)
        }
        return await execute(conversation: conversation)
    }

    /// Scores an already-loaded conversation, for view models that observe it and re-score on change.
    public func execute(conversation: Conversation) async -> TrustReport {
        let metadataStripping = await preferences.isMetadataStrippingEnabled()
        let signals = TrustSignals(
            contact: conversation.contact,
            disappearingTimer: conversation.disappearingTimer,
            metadataStrippingEnabled: metadataStripping,
            now: clock.now()
        )
        let report = evaluator.evaluate(signals)
        CoreLog.security.debug(
            "trust evaluated level=\(report.level.rawValue, privacy: .public) percent=\(report.percent, privacy: .public)"
        )
        return report
    }

    /// Pure scoring for callers that already hold the signals (settings previews, what-if toggles).
    public func execute(signals: TrustSignals) -> TrustReport {
        evaluator.evaluate(signals)
    }
}
