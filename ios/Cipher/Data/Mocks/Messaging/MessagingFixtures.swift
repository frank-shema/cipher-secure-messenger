import CipherCore
import Foundation

/// Rich, deterministic messaging data for previews: five inbox rows and one thread that exercises
/// every bubble state. Everything is built relative to `now` so capsules, countdowns and "last seen"
/// read naturally whenever the preview renders.
enum MessagingFixtures {
    static let me = Fixtures.alice

    static let maraId = UserID(uuidString: "3b7e9c2a-4d5f-4a6b-8c9d-0e1f2a3b4c5d") ?? UserID()
    static let devrajId = UserID(uuidString: "6c8f0d3b-5e6a-4b7c-9dae-1f2a3b4c5d6e") ?? UserID()
    static let sofiaId = UserID(uuidString: "7d9a1e4c-6f7b-4c8d-8ebf-2a3b4c5d6e7f") ?? UserID()

    static let mara = User(id: maraId, username: "mara_k", displayName: "Mara Kovač")
    static let devraj = User(id: devrajId, username: "devraj", displayName: "Devraj Iyer")
    static let sofia = User(id: sofiaId, username: "sofia_l", displayName: "Sofía Lindqvist")

    static let bobConversationId = ConversationID(uuidString: "0c9f2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f") ?? ConversationID()
    static let echoConversationId = ConversationID(uuidString: "1d0a3c8f-2b3c-4d4e-9fa0-1b2c3d4e5f60") ?? ConversationID()
    static let maraConversationId = ConversationID(uuidString: "2e1b4d90-3c4d-4e5f-8ab1-2c3d4e5f6071") ?? ConversationID()
    static let devrajConversationId = ConversationID(uuidString: "3f2c5ea1-4d5e-4f60-9bc2-3d4e5f607182") ?? ConversationID()
    static let sofiaConversationId = ConversationID(uuidString: "403d6fb2-5e6f-4071-8cd3-4e5f60718293") ?? ConversationID()

    static let bobChat = Thread(id: bobConversationId, peer: Fixtures.bob)
    static let echoChat = Thread(id: echoConversationId, peer: Fixtures.echo)
    static let maraChat = Thread(id: maraConversationId, peer: mara)
    static let devrajChat = Thread(id: devrajConversationId, peer: devraj)
    static let sofiaChat = Thread(id: sofiaConversationId, peer: sofia)

    static func contacts(now: Date) -> [Contact] {
        [
            bobContact(now: now),
            Contact(user: Fixtures.echo, keys: Fixtures.keyBundle(for: Fixtures.echo), trust: .unverified,
                    presence: Presence(online: true, lastSeenAt: now)),
            Contact(user: mara, keys: Fixtures.keyBundle(for: mara, version: 2),
                    trust: .keyChanged(previousVersion: 1, at: now.addingTimeInterval(-3_600)),
                    presence: Presence(online: false, lastSeenAt: now.addingTimeInterval(-3_600 * 5))),
            Contact(user: devraj, keys: Fixtures.keyBundle(for: devraj), trust: .unverified,
                    presence: Presence(online: false, lastSeenAt: now.addingTimeInterval(-86_400 * 2))),
            Contact(user: sofia, keys: Fixtures.keyBundle(for: sofia), trust: .verified(at: now.addingTimeInterval(-86_400 * 30)),
                    presence: Presence(online: false, lastSeenAt: nil))
        ]
    }

    static func bobContact(now: Date) -> Contact {
        Contact(user: Fixtures.bob, keys: Fixtures.keyBundle(for: Fixtures.bob),
                trust: .verified(at: now.addingTimeInterval(-86_400 * 3)), presence: Presence(online: true, lastSeenAt: now))
    }

    /// The thread every chat preview opens: verified contact, online, two unread.
    static func bobConversation(now: Date) -> Conversation {
        Conversation(id: bobConversationId, contact: bobContact(now: now), lastMessage: bobThread(now: now).last,
                     unreadCount: 2, updatedAt: now.addingTimeInterval(-40), disappearingTimer: nil)
    }

    static func conversations(now: Date) -> [Conversation] {
        let contacts = contacts(now: now)
        let day: TimeInterval = 86_400
        return [
            bobConversation(now: now),
            Conversation(id: echoConversationId, contact: contacts[1],
                         lastMessage: echoChat.text("Say \"help\" and I will list what I can do.", .incoming,
                                                      at: now.addingTimeInterval(-60 * 25), counter: 3, status: .read),
                         unreadCount: 0, updatedAt: now.addingTimeInterval(-60 * 25), disappearingTimer: nil),
            Conversation(id: maraConversationId, contact: contacts[2],
                         lastMessage: maraChat.tampered(at: now.addingTimeInterval(-3_600 * 2), counter: 12),
                         unreadCount: 1, updatedAt: now.addingTimeInterval(-3_600 * 2), disappearingTimer: day),
            Conversation(id: devrajConversationId, contact: contacts[3],
                         lastMessage: devrajChat.photo(.incoming, at: now.addingTimeInterval(-day - 3_000), counter: 7, status: .read),
                         unreadCount: 0, updatedAt: now.addingTimeInterval(-day - 3_000), disappearingTimer: nil),
            Conversation(id: sofiaConversationId, contact: contacts[4],
                         lastMessage: sofiaChat.text("Landed. Call you after customs.", .outgoing,
                                                       at: now.addingTimeInterval(-day * 4), counter: 41, status: .read),
                         unreadCount: 0, updatedAt: now.addingTimeInterval(-day * 4), disappearingTimer: nil)
        ]
    }

    /// Eighteen messages across two days: grouped runs, a reply, reactions, every attachment mode,
    /// whisper, disappearing, a sealed capsule, tampering, a failed send and system events.
    static func bobThread(now: Date) -> [Message] {
        let thread = bobChat
        let yesterday = now.addingTimeInterval(-86_400)
        let plan = thread.text("Yes. Both halves match, fingerprint checked over the phone.", .outgoing,
                               at: yesterday.addingTimeInterval(45), counter: 1, status: .read)
        var sealed = thread.text("Happy birthday! I set this to open at midnight so you would read it first thing.", .incoming,
                                 at: now.addingTimeInterval(-3_000), counter: 7, status: .delivered)
        sealed.flags.unlockAt = now.addingTimeInterval(95)
        var whisper = thread.text("The safe code is 4471. Hold to read, then forget it.", .incoming,
                                  at: now.addingTimeInterval(-1_500), counter: 8, status: .delivered)
        whisper.flags.whisper = true
        var disappearing = thread.text("This one clears itself in two minutes.", .outgoing,
                                       at: now.addingTimeInterval(-30), counter: 6, status: .read)
        disappearing.flags.disappearAfter = 120
        disappearing.expiresAt = now.addingTimeInterval(90)
        return [
            thread.text("Did the key ceremony go through on your side?", .incoming, at: yesterday, counter: 1, status: .read),
            plan,
            thread.text("Then we are good to move the draft over.", .incoming, at: yesterday.addingTimeInterval(120),
                        counter: 2, status: .read, replyTo: plan.id, reactions: ["🔥"]),
            thread.system(.keyVerified, .outgoing, at: yesterday.addingTimeInterval(300), counter: 2),
            thread.text("Sending the plans now.", .outgoing, at: yesterday.addingTimeInterval(3_600), counter: 3, status: .read),
            thread.photo(.outgoing, at: yesterday.addingTimeInterval(3_610), counter: 4, status: .read),
            thread.file(.incoming, at: yesterday.addingTimeInterval(7_200), counter: 3, status: .read),
            thread.text("Got them. The second page is the one we should talk about.", .incoming,
                        at: yesterday.addingTimeInterval(7_230), counter: 4, status: .read, reactions: ["👍", "😮"]),
            thread.text("Morning. Coffee in ten?", .incoming, at: now.addingTimeInterval(-5_400), counter: 5, status: .read),
            thread.text("On my way", .outgoing, at: now.addingTimeInterval(-5_300), counter: 5, status: .read),
            thread.tampered(at: now.addingTimeInterval(-4_800), counter: 6),
            sealed,
            thread.photo(.incoming, at: now.addingTimeInterval(-2_400), counter: 9, status: .delivered, viewOnce: true),
            thread.system(.disappearingChanged, .incoming, at: now.addingTimeInterval(-2_000), counter: 10),
            whisper,
            disappearing,
            thread.text("Also, this one never left the phone.", .outgoing, at: now.addingTimeInterval(-20), counter: 7, status: .failed),
            thread.text("Sending you the address in a sec", .outgoing, at: now.addingTimeInterval(-5), counter: 8, status: .sending)
        ]
    }
}
