import Foundation

/// Invented people and conversations for the decoy inbox. Everything here is fiction written to be
/// forgettable: errands, plans, small talk. Nothing references a real person, place of work or
/// account, and nothing is worth asking follow-up questions about.
enum DecoyScripts {
    struct Persona: Hashable, Sendable {
        var displayName: String
        var username: String
    }

    struct Line: Hashable, Sendable {
        var direction: MessageDirection
        var text: String
    }

    static let personas: [Persona] = [
        Persona(displayName: "Maya Okafor", username: "maya_o"),
        Persona(displayName: "Tomas Lindqvist", username: "tomas_l"),
        Persona(displayName: "Priya Raman", username: "priya_r"),
        Persona(displayName: "Dana Whitfield", username: "dana_w"),
        Persona(displayName: "Leo Marchetti", username: "leo_m"),
        Persona(displayName: "Sam Delacroix", username: "sam_d"),
        Persona(displayName: "Ines Ferreira", username: "ines_f"),
        Persona(displayName: "Kenji Watanabe", username: "kenji_w"),
        Persona(displayName: "Rosa Almeida", username: "rosa_a"),
        Persona(displayName: "Noah Petrov", username: "noah_p")
    ]

    static let scripts: [[Line]] = [
        [
            Line(direction: .incoming, text: "Still on for dinner Thursday?"),
            Line(direction: .outgoing, text: "Yes! 7:30 at the Thai place?"),
            Line(direction: .incoming, text: "Perfect. I'll book a table for four."),
            Line(direction: .outgoing, text: "Can you make it five, Jo might join"),
            Line(direction: .incoming, text: "Done. Five it is."),
            Line(direction: .outgoing, text: "You're a star, thanks")
        ],
        [
            Line(direction: .outgoing, text: "Did the plumber ever call back?"),
            Line(direction: .incoming, text: "Coming Tuesday between 9 and 12"),
            Line(direction: .outgoing, text: "Great, I'll work from home that morning"),
            Line(direction: .incoming, text: "He said it's probably just the washer"),
            Line(direction: .outgoing, text: "Fingers crossed. The drip is driving me mad"),
            Line(direction: .incoming, text: "Ha, I know. I can hear it from the hallway"),
            Line(direction: .outgoing, text: "Okay okay I'll put a bucket under it tonight")
        ],
        [
            Line(direction: .incoming, text: "Book club moved to the 28th, does that still work?"),
            Line(direction: .outgoing, text: "Works for me. I'm only halfway through though"),
            Line(direction: .incoming, text: "Same. The middle section drags a bit"),
            Line(direction: .outgoing, text: "Glad it's not just me"),
            Line(direction: .incoming, text: "Bring the lemon cake again if you can!"),
            Line(direction: .outgoing, text: "Deal.")
        ],
        [
            Line(direction: .outgoing, text: "Gym at 6 tomorrow?"),
            Line(direction: .incoming, text: "Ugh. Fine. But you're buying the coffee after"),
            Line(direction: .outgoing, text: "Fair"),
            Line(direction: .incoming, text: "Leg day or are we skipping it again"),
            Line(direction: .outgoing, text: "We are absolutely skipping it again"),
            Line(direction: .incoming, text: "Respect")
        ],
        [
            Line(direction: .incoming, text: "Any ideas for mum's birthday present?"),
            Line(direction: .outgoing, text: "She mentioned wanting a new garden kneeler thing"),
            Line(direction: .incoming, text: "A what"),
            Line(direction: .outgoing, text: "The padded thing you kneel on for weeding"),
            Line(direction: .incoming, text: "Oh right. I'll look tonight"),
            Line(direction: .outgoing, text: "Split it?"),
            Line(direction: .incoming, text: "Obviously"),
            Line(direction: .outgoing, text: "Send me the link when you find one")
        ],
        [
            Line(direction: .outgoing, text: "The hike on Saturday - are we doing the long loop?"),
            Line(direction: .incoming, text: "Forecast says rain after 2, so maybe the short one"),
            Line(direction: .outgoing, text: "Short one and then the pub"),
            Line(direction: .incoming, text: "Now you're talking"),
            Line(direction: .outgoing, text: "I'll bring the good snacks"),
            Line(direction: .incoming, text: "The cheese crackers or it doesn't count")
        ],
        [
            Line(direction: .incoming, text: "Viewing for the flat is at 5:15, I'll meet you outside"),
            Line(direction: .outgoing, text: "On my way, running 10 late"),
            Line(direction: .incoming, text: "No stress, the agent is late too"),
            Line(direction: .outgoing, text: "Classic"),
            Line(direction: .incoming, text: "The kitchen is smaller than in the photos btw"),
            Line(direction: .outgoing, text: "They always are")
        ],
        [
            Line(direction: .outgoing, text: "Can you send me that soup recipe?"),
            Line(direction: .incoming, text: "Roast the squash first, then onion, stock, blitz. Salt at the end"),
            Line(direction: .outgoing, text: "That's it??"),
            Line(direction: .incoming, text: "Plus a lot of butter. Don't tell anyone"),
            Line(direction: .outgoing, text: "Your secret is safe"),
            Line(direction: .incoming, text: "Let me know how it turns out!")
        ],
        [
            Line(direction: .incoming, text: "Left my charger at yours, can I grab it Sunday?"),
            Line(direction: .outgoing, text: "Sure, I'm around after 11"),
            Line(direction: .incoming, text: "Great, I'll bring the tupperware back too"),
            Line(direction: .outgoing, text: "Finally"),
            Line(direction: .incoming, text: "It's been like two weeks, relax")
        ],
        [
            Line(direction: .outgoing, text: "Train's delayed again. 20 minutes"),
            Line(direction: .incoming, text: "Want me to pick you up from the station instead?"),
            Line(direction: .outgoing, text: "That would be amazing"),
            Line(direction: .incoming, text: "Text me when you're two stops away"),
            Line(direction: .outgoing, text: "Will do"),
            Line(direction: .incoming, text: "See you soon")
        ]
    ]

    /// Reactions sprinkled onto the occasional enthusiastic line so threads look lived-in.
    static let reactions: [String] = ["👍", "❤️", "😂", "🙌"]
}
