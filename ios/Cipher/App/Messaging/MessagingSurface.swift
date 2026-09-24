import CipherCore
import Foundation

/// What the signed-in screens run on: the dependency bundles for the inbox, a chat and the
/// verification screen. There is one surface per active inbox, whichever it is: the real account
/// stack, the in-memory previews, or the decoy inbox after a duress unlock. Screens never learn which.
struct MessagingSurface: Identifiable, Sendable {
    /// Changes whenever the surface is swapped, so screens rebuild their view models.
    let id: UUID
    let account: User
    let list: ConversationListDependencies
    let chat: ChatDependencies
    let verify: VerifyDependencies
    /// True while the duress inbox is showing; Settings hides sign-out and the lock rows then.
    let isDecoy: Bool

    init(account: User, list: ConversationListDependencies, chat: ChatDependencies, verify: VerifyDependencies, isDecoy: Bool) {
        self.id = UUID()
        self.account = account
        self.list = list
        self.chat = chat
        self.verify = verify
        self.isDecoy = isDecoy
    }

    /// Resolves a route's conversation id against this surface's store.
    func conversation(id: ConversationID) async -> Conversation? {
        do {
            return try await chat.conversations.fetch(id: id)
        } catch {
            let failure = String(describing: type(of: error))
            AppLog.messaging.error("conversation \(id.description, privacy: .public) lookup failed: \(failure, privacy: .public)")
            return nil
        }
    }

    /// The duress inbox: fictional, in memory, never touching the relay. Verification still works on
    /// the decoy contacts so the screen behaves exactly like the real one.
    static func decoy(
        _ provider: DecoyInboxProvider,
        account: User,
        identityKeys: any IdentityKeyStore,
        clock: any Clock
    ) -> MessagingSurface {
        let chat = provider.chatDependencies
        let verify = VerifyDependencies(
            currentUser: account,
            contacts: chat.contacts,
            identityKeys: identityKeys,
            verify: VerifyContactUseCase(contacts: chat.contacts, clock: clock),
            clock: clock
        )
        return MessagingSurface(account: account, list: provider.listDependencies, chat: chat, verify: verify, isDecoy: true)
    }
}

/// A running account: its surface plus the lifecycle the coordinator drives. Production is
/// `AccountRuntime` (socket, sweeps, outbox); previews use `PreviewMessagingRuntime`.
@MainActor
protocol ActiveMessaging: AnyObject {
    var surface: MessagingSurface { get }
    /// Reports socket state for the inbox banner.
    var onConnectionChange: @MainActor (RealtimeConnectionState) -> Void { get set }
    /// Starts pumps and connects; idempotent.
    func start() async
    /// Tears everything down for sign-out.
    func stop() async
    /// Background or duress: disconnect so the relay sees no activity, pause sweeps.
    func suspend() async
    /// Foreground again: reconnect and sweep what expired meanwhile.
    func resume() async
}
