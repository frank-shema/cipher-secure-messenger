import Foundation

/// Runs the sensitive-content detector off the caller's actor so a ViewModel can scan on every
/// debounced keystroke without touching the main thread. Logs kinds and counts only: the scanned
/// text is a draft the person has not agreed to send anywhere.
public struct DetectSensitiveContentUseCase: Sendable {
    private let detector: SensitiveContentDetector

    public init(detector: SensitiveContentDetector = SensitiveContentDetector()) {
        self.detector = detector
    }

    /// Scans a draft. Safe to call from `@MainActor`; the work hops to the cooperative pool.
    public func execute(text: String) async -> [SensitiveFinding] {
        let detector = self.detector
        let findings = await Task.detached(priority: .userInitiated) {
            detector.detect(in: text)
        }.value
        if !findings.isEmpty {
            let kinds = Set(findings.map(\.kind.rawValue)).sorted().joined(separator: ",")
            CoreLog.security.debug("sensitive content: \(findings.count, privacy: .public) finding(s) kinds=\(kinds, privacy: .public)")
        }
        return findings
    }

    /// Scans the text body of an outgoing payload; attachments, reactions and system events have no
    /// free text to inspect and yield no findings.
    public func execute(payload: MessagePayload) async -> [SensitiveFinding] {
        guard let body = payload.body, !body.isEmpty else { return [] }
        return await execute(text: body)
    }
}
