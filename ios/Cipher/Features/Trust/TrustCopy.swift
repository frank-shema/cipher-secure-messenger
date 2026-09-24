import CipherCore
import CipherDesign
import Foundation

/// Plain-English wording for the trust sheet. Core emits catalog keys (`trust.reason.<kind>.title`);
/// the literal keys here match them one for one so the catalog stays greppable and translators see
/// the English default next to each key.
enum TrustCopy {
    static func headline(for level: TrustLevel) -> String {
        switch level {
        case .high:
            String(localized: "trust.level.high", defaultValue: "Strong protection")
        case .medium:
            String(localized: "trust.level.medium", defaultValue: "Good, with room to improve")
        case .low:
            String(localized: "trust.level.low", defaultValue: "Needs your attention")
        }
    }

    static func summary(satisfied: Int, total: Int) -> String {
        String(localized: "trust.sheet.summary", defaultValue: "\(satisfied) of \(total) protections in place")
    }

    static func actionTitle(for action: TrustAction) -> String {
        switch action {
        case .verifyKeys:
            String(localized: "trust.action.verifyKeys", defaultValue: "Verify keys")
        case .enableDisappearing:
            String(localized: "trust.action.enableDisappearing", defaultValue: "Enable disappearing")
        case .reviewKeyChange:
            String(localized: "trust.action.reviewKeyChange", defaultValue: "Review key change")
        }
    }

    static func title(for kind: TrustReason.Kind) -> String {
        switch kind {
        case .keyChanged:
            String(localized: "trust.reason.keyChanged.title", defaultValue: "Safety keys changed recently")
        case .keysUnverified:
            String(localized: "trust.reason.keysUnverified.title", defaultValue: "Keys not verified yet")
        case .keysVerified:
            String(localized: "trust.reason.keysVerified.title", defaultValue: "Keys verified by you")
        case .keyFresh:
            String(localized: "trust.reason.keyFresh.title", defaultValue: "Keys are new")
        case .keyEstablished:
            String(localized: "trust.reason.keyEstablished.title", defaultValue: "Keys are established")
        case .disappearingOff:
            String(localized: "trust.reason.disappearingOff.title", defaultValue: "Messages stay forever")
        case .disappearingOn:
            String(localized: "trust.reason.disappearingOn.title", defaultValue: "Messages disappear")
        case .metadataStrippingOff:
            String(localized: "trust.reason.metadataStrippingOff.title", defaultValue: "Photo metadata kept")
        case .metadataStrippingOn:
            String(localized: "trust.reason.metadataStrippingOn.title", defaultValue: "Photo metadata stripped")
        }
    }

    /// The one-sentence explanation, phrased around the contact and the actual dates so the sheet
    /// reads like a person explaining it rather than a checklist.
    static func detail(for kind: TrustReason.Kind, contact: Contact, disappearingTimer: TimeInterval?, now: Date) -> String {
        let name = contact.user.displayName
        switch kind {
        case .keyChanged:
            let when = keyChangeDate(contact.trust).map { Self.absolute($0) } ?? Self.recently
            return String(
                localized: "trust.reason.keyChanged.detail",
                defaultValue: """
                \(name)'s keys changed \(when). Until you compare safety codes again, \
                this could be a new phone or someone in the middle.
                """
            )
        case .keysUnverified:
            return String(
                localized: "trust.reason.keysUnverified.detail",
                defaultValue: """
                Compare safety codes with \(name) in person or on a call. \
                It is the only way to rule out an impersonating relay.
                """
            )
        case .keysVerified:
            let when = verifiedDate(contact.trust).map { Self.absolute($0) } ?? Self.recently
            return String(
                localized: "trust.reason.keysVerified.detail",
                defaultValue: "You compared safety codes with \(name) \(when). The relay cannot swap keys without you noticing."
            )
        case .keyFresh:
            let when = contact.keys.map { $0.createdAt.formatted(.relative(presentation: .named)) } ?? Self.recently
            return String(
                localized: "trust.reason.keyFresh.detail",
                defaultValue: "\(name)'s keys were published \(when). Keys that stay unchanged for a month earn a little more trust."
            )
        case .keyEstablished:
            return String(
                localized: "trust.reason.keyEstablished.detail",
                defaultValue: "\(name)'s keys have stayed the same for over a month."
            )
        case .disappearingOff:
            return String(
                localized: "trust.reason.disappearingOff.detail",
                defaultValue: "Set a timer so messages delete on both phones after they are read."
            )
        case .disappearingOn:
            let timer = CountdownRing.label(forRemaining: disappearingTimer ?? 0)
            return String(
                localized: "trust.reason.disappearingOn.detail",
                defaultValue: "Messages delete on both phones \(timer) after they are read."
            )
        case .metadataStrippingOff:
            return String(
                localized: "trust.reason.metadataStrippingOff.detail",
                defaultValue: "Location and camera details are sent along with photos."
            )
        case .metadataStrippingOn:
            return String(
                localized: "trust.reason.metadataStrippingOn.detail",
                defaultValue: "Location, camera and timestamp details are removed from photos before they are encrypted."
            )
        }
    }

    private static var recently: String {
        String(localized: "trust.date.recently", defaultValue: "recently")
    }

    private static func absolute(_ date: Date) -> String {
        String(localized: "trust.date.on", defaultValue: "on \(date.formatted(date: .abbreviated, time: .omitted))")
    }

    private static func keyChangeDate(_ trust: TrustState) -> Date? {
        if case .keyChanged(_, let at) = trust { return at }
        return nil
    }

    private static func verifiedDate(_ trust: TrustState) -> Date? {
        if case .verified(let at) = trust { return at }
        return nil
    }
}
