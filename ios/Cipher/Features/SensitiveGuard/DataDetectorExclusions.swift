import Foundation

/// Spans of a draft that Foundation's data detector recognises as something ordinary: a phone number
/// or a link. The Core scanners see only characters, so "+1 415 555 0134" reads like a one-time code
/// and "https://x.io/a8Fk2!q" like a password; the system detector knows better and vetoes them.
///
/// `NSDataDetector` is immutable after creation and documented thread-safe, which is why the wrapper
/// can be `@unchecked Sendable` and shared by the guard actor.
struct DataDetectorExclusions: @unchecked Sendable {
    /// Ranges grouped by what the detector saw, in the coordinates of the scanned string.
    struct Spans: Sendable {
        var links: [Range<String.Index>] = []
        var phoneNumbers: [Range<String.Index>] = []

        var isEmpty: Bool { links.isEmpty && phoneNumbers.isEmpty }

        func coversLink(_ range: Range<String.Index>) -> Bool {
            links.contains { $0.overlaps(range) }
        }

        func coversPhoneNumber(_ range: Range<String.Index>) -> Bool {
            phoneNumbers.contains { $0.overlaps(range) }
        }
    }

    private let detector: NSDataDetector?

    init() {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .link]
        detector = try? NSDataDetector(types: types.rawValue)
        if detector == nil {
            SensitiveGuardLog.guardian.notice("data detector unavailable; phone and link exclusions disabled")
        }
    }

    func spans(in text: String) -> Spans {
        guard let detector, !text.isEmpty else { return Spans() }
        var spans = Spans()
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, options: [], range: whole) {
            guard let range = Range(match.range, in: text) else { continue }
            switch match.resultType {
            case .link:
                spans.links.append(range)
            case .phoneNumber:
                spans.phoneNumbers.append(range)
            default:
                continue
            }
        }
        return spans
    }
}
