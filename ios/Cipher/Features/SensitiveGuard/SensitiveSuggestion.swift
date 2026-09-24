import CipherCore
import Foundation

/// The guard's verdict on a draft: what it looks like, how sure the guard is, the sentence the chip
/// shows and the flags the composer applies when the person accepts. Keeping copy and flags on one
/// value means the chip can never promise a timer the send does not honour.
struct SensitiveSuggestion: Hashable, Sendable {
    /// Seconds after read until both phones delete an accepted message. Sixty is long enough to read
    /// and copy a code, short enough that a forgotten unlock does not sit in a transcript for weeks.
    static let disappearAfter: TimeInterval = 60

    var kind: SensitiveKind
    /// 0…1 from the underlying scanner, kept so a host can choose a quieter treatment for weak hits.
    var confidence: Double

    init(kind: SensitiveKind, confidence: Double) {
        self.kind = kind
        self.confidence = min(max(confidence, 0), 1)
    }

    /// The chip sentence, e.g. "Looks like a password. Send as view-once and auto-delete in 1 minute?"
    var message: String {
        SensitiveGuardCopy.message(for: kind)
    }

    /// The flags an accepted suggestion sets: the recipient can open the message once, and both
    /// sides delete it a minute after it is read. Whisper and Time Capsule are left as the person had them.
    func apply(to flags: MessageFlags) -> MessageFlags {
        var updated = flags
        updated.viewOnce = true
        updated.disappearAfter = Self.disappearAfter
        return updated
    }

    /// The flags for a message that had none before the suggestion.
    var acceptedFlags: MessageFlags {
        apply(to: .none)
    }
}

/// Wording and symbols for the guard's chip and settings. Kinds map to literal catalog keys so the
/// catalog stays greppable; the auto-delete window is interpolated from the constant it describes.
enum SensitiveGuardCopy {
    /// "1 minute", derived from `SensitiveSuggestion.disappearAfter` so copy and behaviour cannot drift.
    static var disappearWindow: String {
        Duration.seconds(SensitiveSuggestion.disappearAfter).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    static func message(for kind: SensitiveKind) -> String {
        let window = disappearWindow
        switch kind {
        case .password:
            return String(
                localized: "sensitiveGuard.chip.password",
                defaultValue: "Looks like a password. Send as view-once and auto-delete in \(window)?"
            )
        case .cardNumber:
            return String(
                localized: "sensitiveGuard.chip.cardNumber",
                defaultValue: "Looks like a card number. Send as view-once and auto-delete in \(window)?"
            )
        case .iban:
            return String(
                localized: "sensitiveGuard.chip.iban",
                defaultValue: "Looks like a bank account number. Send as view-once and auto-delete in \(window)?"
            )
        case .oneTimeCode:
            return String(
                localized: "sensitiveGuard.chip.oneTimeCode",
                defaultValue: "Looks like a one-time code. Send as view-once and auto-delete in \(window)?"
            )
        }
    }

    static func symbol(for kind: SensitiveKind) -> String {
        switch kind {
        case .password: "key.horizontal.fill"
        case .cardNumber: "creditcard.fill"
        case .iban: "building.columns.fill"
        case .oneTimeCode: "number.circle.fill"
        }
    }

    /// Bank details outrank a card, which outranks a password guess, which outranks a code that
    /// expires in minutes anyway: when several secrets sit in one draft, the chip names the worst leak.
    static func severity(of kind: SensitiveKind) -> Int {
        switch kind {
        case .iban: 4
        case .cardNumber: 3
        case .password: 2
        case .oneTimeCode: 1
        }
    }
}
