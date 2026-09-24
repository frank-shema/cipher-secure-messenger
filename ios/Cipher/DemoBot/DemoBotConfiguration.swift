#if DEBUG
import CipherNetworking
import Foundation

/// The relay account the companion signs in as. Fixed, in the spirit of the `alice` / `cipher-alice`
/// examples in PROTOCOL.md, so every developer's simulator talks to the same `echo` identity on their
/// own local relay.
struct DemoBotCredentials: Hashable, Sendable {
    var username: String
    var password: String
    var displayName: String

    static let echo = DemoBotCredentials(username: "echo", password: "cipher-echo", displayName: "Echo")
}

/// Everything that shapes the companion's behaviour, in one value, so the Settings toggle and the
/// self-test build the same bot and only the timings differ.
struct DemoBotConfiguration: Sendable {
    /// The relay the bot talks to. Always the app's own relay (including the Settings override): the
    /// demo is precisely that two independent clients meet only through the same blind relay.
    var api: APIConfiguration
    var credentials: DemoBotCredentials
    /// Keychain service for the companion's private keys. Separate from the app's identity service so
    /// the two identities can never overwrite or read each other.
    var keychainService: String
    /// How long "typing…" shows before a reply, drawn per message so the pacing reads as a person
    /// rather than a timer.
    var thinkingDelayMillis: ClosedRange<Int>
    /// Pause between the reply and the read receipt, so the double check lands after the bubble.
    var readReceiptDelay: Duration
    /// How far in the future a `capsule` reply unlocks.
    var capsuleDelay: TimeInterval
    /// Messages older than this when the bot connects are acknowledged and read but not answered: a
    /// backlog left over from a previous session must not turn into a burst of stale replies.
    var backlogGrace: TimeInterval

    init(
        api: APIConfiguration,
        credentials: DemoBotCredentials = .echo,
        keychainService: String = "com.cipher.demo.echo",
        thinkingDelayMillis: ClosedRange<Int> = 600...1_200,
        readReceiptDelay: Duration = .milliseconds(1_500),
        capsuleDelay: TimeInterval = 30,
        backlogGrace: TimeInterval = 60
    ) {
        self.api = api
        self.credentials = credentials
        self.keychainService = keychainService
        self.thinkingDelayMillis = thinkingDelayMillis
        self.readReceiptDelay = readReceiptDelay
        self.capsuleDelay = capsuleDelay
        self.backlogGrace = backlogGrace
    }

    /// Mirrors the app's resolved relay endpoints, override included.
    init(endpoints: ServerEndpoints) {
        self.init(api: APIConfiguration(baseURL: endpoints.baseURL, webSocketURL: endpoints.webSocketURL))
    }

    /// A fresh draw from `thinkingDelayMillis`.
    var thinkingDelay: Duration {
        .milliseconds(Int.random(in: thinkingDelayMillis))
    }
}
#endif
