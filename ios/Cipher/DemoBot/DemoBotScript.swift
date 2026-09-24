#if DEBUG
import CipherCore
import Foundation

/// Decides what Echo does with an incoming message. Pure: the plan is a value computed from the
/// message and a small context, and the responder carries it out, so the personality can be read
/// (and later tested) without a relay in sight.
enum DemoBotScript {
    struct Context: Hashable, Sendable {
        /// Echo has never spoken to this person on this device.
        var isFirstContact: Bool
        /// The disappearing timer Echo believes this conversation uses (see `DemoBotResponder`).
        var disappearingTimer: TimeInterval?
        var capsuleDelay: TimeInterval
        var seed: UInt64
    }

    enum Action: Hashable, Sendable {
        case text(String)
        case whisper(String)
        case capsule(String)
        case photo(caption: String)
    }

    struct Plan: Hashable, Sendable {
        var reaction: String?
        var actions: [Action]
        /// Answer as a quoted reply, because the person quoted Echo.
        var quotes: Bool
        /// The plan opens with the first-contact greeting; remember the person once it is delivered.
        var greets: Bool

        static let silent = Plan(reaction: nil, actions: [], quotes: false, greets: false)

        var isSilent: Bool {
            reaction == nil && actions.isEmpty
        }
    }

    static func plan(for message: Message, context: Context) -> Plan {
        var plan: Plan
        switch message.content {
        case .text(let body):
            plan = planText(body, context: context)
        case .attachment(let attachment, _):
            plan = Plan(reaction: nil, actions: [.text(DemoBotPhrases.receivedAttachment(attachment))], quotes: false, greets: false)
        case .system(let event):
            let line = DemoBotPhrases.system(event.kind)
            plan = Plan(reaction: nil, actions: line.map { [.text($0)] } ?? [], quotes: false, greets: false)
        case .tampered(let reason):
            // A replay is the relay (or a test) re-sending something already answered; stay quiet.
            plan = reason == .replayed
                ? .silent
                : Plan(reaction: nil, actions: [.text(DemoBotPhrases.tampered)], quotes: false, greets: false)
        case .reaction:
            return .silent
        }
        guard !plan.isSilent else { return plan }
        plan.quotes = message.replyToId != nil
        if context.isFirstContact {
            plan.actions.insert(.text(DemoBotPhrases.greeting), at: 0)
            plan.greets = true
        }
        return plan
    }

    /// `!` earns a 🔥 and a heart earns a ❤️, hearts winning when both appear.
    static func reaction(for body: String) -> String? {
        if body.contains("❤️") || body.contains("❤") || body.contains("💜") {
            return "❤️"
        }
        if body.contains("!") {
            return "🔥"
        }
        return nil
    }

    private static func planText(_ body: String, context: Context) -> Plan {
        let actions: [Action]
        switch DemoBotCommand(text: body) {
        case .help:
            actions = [.text(DemoBotPhrases.help(capsuleSeconds: Int(context.capsuleDelay)))]
        case .photo:
            actions = [.photo(caption: DemoBotPhrases.photoCaption)]
        case .capsule:
            actions = [.capsule(DemoBotPhrases.capsule(sealedAt: Date(), seconds: Int(context.capsuleDelay)))]
        case .whisper:
            actions = [.whisper(DemoBotPhrases.whisper)]
        case .disappear:
            actions = [.text(DemoBotPhrases.disappearing(timer: context.disappearingTimer))]
        case .ping:
            actions = [.text(DemoBotPhrases.pong)]
        case .greeting:
            actions = [.text(context.isFirstContact ? DemoBotPhrases.helpHint : DemoBotPhrases.greetingAgain)]
        case nil:
            actions = [.text(DemoBotTwist.apply(to: body, seed: context.seed))]
        }
        return Plan(reaction: reaction(for: body), actions: actions, quotes: false, greets: false)
    }
}
#endif
