import Foundation

/// Scans a draft for secrets before it is sent so the composer can suggest a whisper, a view-once
/// send or a redaction. Runs every scanner, drops overlapping hits in favour of the more specific
/// kind, and filters by a minimum confidence so the UI never nags over weak evidence.
public struct SensitiveContentDetector: Sendable {
    public struct Configuration: Hashable, Sendable {
        /// Drafts longer than this are scanned only up to the limit; a pasted novel should not stall
        /// the composer, and secrets are overwhelmingly short messages anyway.
        public var maximumScannedCharacters: Int
        /// Findings below this confidence are discarded.
        public var minimumConfidence: Double

        public init(maximumScannedCharacters: Int = 20_000, minimumConfidence: Double = 0.55) {
            self.maximumScannedCharacters = maximumScannedCharacters
            self.minimumConfidence = minimumConfidence
        }

        public static let `default` = Configuration()
    }

    public var configuration: Configuration
    private let scanners: [any SensitiveContentScanner]

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.scanners = [IBANScanner(), CardNumberScanner(), PasswordScanner(), OneTimeCodeScanner()]
    }

    /// Findings sorted by position, non-overlapping, above the configured confidence.
    public func detect(in text: String) -> [SensitiveFinding] {
        guard !text.isEmpty else { return [] }
        let scanned = text.count > configuration.maximumScannedCharacters
            ? String(text.prefix(configuration.maximumScannedCharacters))
            : text
        let raw = scanners.flatMap { $0.scan(scanned) }
            .filter { $0.confidence >= configuration.minimumConfidence }
        let merged = Self.resolveOverlaps(raw)
        return merged.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The single most severe finding, for a one-line composer hint.
    public func mostSevereFinding(in text: String) -> SensitiveFinding? {
        detect(in: text).max { lhs, rhs in rhs.outranks(lhs) }
    }

    /// Greedy resolution: process by rank, keep a finding only if nothing already kept overlaps it.
    private static func resolveOverlaps(_ findings: [SensitiveFinding]) -> [SensitiveFinding] {
        let ranked = findings.sorted { $0.outranks($1) }
        var kept: [SensitiveFinding] = []
        for candidate in ranked where !kept.contains(where: { $0.overlaps(candidate) }) {
            kept.append(candidate)
        }
        return kept
    }
}
