import CipherCore
import Foundation
import Observation

/// Drives the trust ring and the "Why this chat is secure" sheet for one conversation. Scoring is a
/// pure Core function over the contact's pinned keys, the conversation timer and the metadata policy;
/// this class only decides when to re-run it and what to show while the first run is in flight.
@MainActor
@Observable
final class TrustRingViewModel {
    /// Eight segments, the same as the chat header ring, so the sheet and the header read as one
    /// instrument rather than two different meters.
    static let segments = 8

    private(set) var conversation: Conversation
    private(set) var report: TrustReport?
    private(set) var isEvaluating = false

    @ObservationIgnored private let evaluator: any TrustEvaluating
    @ObservationIgnored private let contacts: (any ContactRepository)?
    @ObservationIgnored private var evaluation: Task<Void, Never>?
    @ObservationIgnored private var contactObservation: Task<Void, Never>?

    /// - Parameters:
    ///   - conversation: The conversation to score; the embedded contact carries keys and trust.
    ///   - evaluator: The scoring use case (or a preview stand-in).
    ///   - contacts: When supplied, the model follows the contact so a verification completed while
    ///     the sheet is open moves the ring without the host having to push a new conversation in.
    init(conversation: Conversation, evaluator: any TrustEvaluating, contacts: (any ContactRepository)? = nil) {
        self.conversation = conversation
        self.evaluator = evaluator
        self.contacts = contacts
    }

    var contact: Contact { conversation.contact }
    var segments: Int { Self.segments }

    /// Until the first evaluation lands, the ring shows the same coarse fill the chat header uses, so
    /// opening the sheet never flashes an empty ring before settling.
    var score: Double { report?.score ?? contact.trust.ringScore }

    var percent: Int { report?.percent ?? Int((score * 100).rounded()) }

    /// Before the report lands, the fallback score is bucketed with the evaluator's own thresholds so
    /// the headline never contradicts the report that replaces it.
    var level: TrustLevel {
        if let report { return report.level }
        let weights = TrustEvaluator.Weights.default
        if score >= weights.highThreshold { return .high }
        if score >= weights.mediumThreshold { return .medium }
        return .low
    }

    var reasons: [TrustReason] { report?.reasons ?? [] }
    var openReasons: [TrustReason] { report?.openReasons ?? [] }
    var satisfiedCount: Int { reasons.filter(\.isSatisfied).count }
    var recommendedAction: TrustAction? { report?.recommendedAction }
    var hasRecentKeyChange: Bool { reasons.contains { $0.kind == .keyChanged } }

    // MARK: Lifecycle

    /// Evaluates once and, when a contact repository was supplied, keeps following the contact.
    func start() {
        evaluate()
        guard contactObservation == nil, let contacts else { return }
        let userId = contact.id
        contactObservation = Task { [weak self] in
            let stream = await contacts.observe(userId: userId)
            for await updated in stream {
                guard !Task.isCancelled, let self else { return }
                guard updated != conversation.contact else { continue }
                conversation.contact = updated
                evaluate()
            }
        }
    }

    func stop() {
        evaluation?.cancel()
        evaluation = nil
        contactObservation?.cancel()
        contactObservation = nil
    }

    /// Hosts that already observe the conversation (the chat screen) push changes in here; a timer
    /// change or a new key bundle re-scores immediately.
    func update(conversation: Conversation) {
        guard conversation != self.conversation else { return }
        self.conversation = conversation
        evaluate()
    }

    /// Re-runs the evaluator. Only the newest run may publish, so a stale result can never overwrite
    /// a fresher one when conversations change quickly.
    func evaluate() {
        evaluation?.cancel()
        isEvaluating = true
        let snapshot = conversation
        evaluation = Task { [weak self] in
            guard let self else { return }
            let result = await evaluator.execute(conversation: snapshot)
            guard !Task.isCancelled else { return }
            report = result
            isEvaluating = false
            let open = result.openReasons.map(\.kind.rawValue).joined(separator: ",")
            let level = result.level.rawValue
            TrustLog.trust.debug(
                "trust ring level=\(level, privacy: .public) percent=\(result.percent, privacy: .public) open=\(open, privacy: .public)"
            )
        }
    }
}
