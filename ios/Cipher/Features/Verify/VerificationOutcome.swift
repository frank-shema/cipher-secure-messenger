import CipherCore
import Foundation

/// How the person proved the fingerprints match.
enum VerificationMethod: Hashable, Sendable {
    /// Their QR code was scanned (or pasted) and matched the pinned keys byte for byte.
    case qrCode
    /// The emoji or safety number were compared out of band and the person confirmed the match.
    case readAloud
}

/// The result of comparing scanned key material with the keys pinned for the contact. Every case is
/// shown on the verification screen; the failures are deliberately loud because a mismatch is the
/// one observable symptom of a relay substituting keys.
enum VerificationOutcome: Hashable, Sendable {
    case matched(VerificationMethod)
    /// The code belongs to the right person but carries different keys than the ones pinned.
    case keyMismatch
    /// The code was made for a different account than the one being verified.
    case wrongPerson

    var isSuccess: Bool {
        if case .matched = self { return true }
        return false
    }

    var systemImage: String {
        switch self {
        case .matched: "checkmark.shield.fill"
        case .keyMismatch: "exclamationmark.shield.fill"
        case .wrongPerson: "person.crop.circle.badge.questionmark"
        }
    }

    var title: String {
        switch self {
        case .matched:
            String(localized: "verify.outcome.matched.title", defaultValue: "Keys verified")
        case .keyMismatch:
            String(localized: "verify.outcome.mismatch.title", defaultValue: "Keys do not match")
        case .wrongPerson:
            String(localized: "verify.outcome.wrongPerson.title", defaultValue: "That code belongs to someone else")
        }
    }

    func message(contactName: String) -> String {
        switch self {
        case .matched(.qrCode):
            String(
                localized: "verify.outcome.matched.qr",
                defaultValue: """
                    \(contactName)'s code matches the keys pinned on this device. \
                    Messages between you are end-to-end encrypted with keys you have both confirmed.
                    """
            )
        case .matched(.readAloud):
            String(
                localized: "verify.outcome.matched.readAloud",
                defaultValue: "You confirmed the codes match. \(contactName) is now marked as verified on this device."
            )
        case .keyMismatch:
            String(
                localized: "verify.outcome.mismatch.message",
                defaultValue: """
                    The keys in this code are different from the keys this device pinned for \(contactName). \
                    Do not send anything sensitive until you have compared codes in person.
                    """
            )
        case .wrongPerson:
            String(
                localized: "verify.outcome.wrongPerson.message",
                defaultValue: "This code was made for a different account. Ask \(contactName) to open their own verification screen."
            )
        }
    }
}

/// Whether the verification screen has enough to show a fingerprint.
enum VerifyPhase: Hashable, Sendable {
    case loading
    case ready
    /// Fingerprints need both key bundles; this names which one is missing.
    case unavailable(String)
}
