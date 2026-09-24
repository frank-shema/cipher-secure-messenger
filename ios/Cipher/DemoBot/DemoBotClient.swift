#if DEBUG
import CipherCore
import CipherCrypto
import CipherNetworking
import CipherPersistence
import Foundation

/// A complete, independent Cipher client for the companion: its own tokens, REST client, gateways,
/// socket, crypto engine, identity keys and (in-memory) store. Only the outgoing counters outlive the
/// process, through `DemoBotMessageRepository`, so a relaunched Echo never repeats a counter. Nothing is shared with the person's
/// account, which is what makes the demo honest: the two sides really do meet only as ciphertext on
/// the relay, and Echo verifies and decrypts exactly the way any other device would.
struct DemoBotClient: Sendable {
    enum Phase: Hashable, Sendable {
        case signingIn
        case publishingKeys
        case connecting
    }

    let user: User
    let stack: MessagingStack
    let realtime: WebSocketClient
    let attachments: RemoteAttachmentGateway
    let tokens: DemoBotTokenProvider

    /// Builds the whole graph: sign in (registering if needed), publish keys, then assemble the
    /// account-scoped stack. `progress` reports each phase so the Settings row can narrate it.
    static func assemble(
        configuration: DemoBotConfiguration,
        memory: DemoBotMemory,
        progress: @Sendable (Phase) async -> Void
    ) async throws -> DemoBotClient {
        await progress(.signingIn)
        let anonymous = APIClient(configuration: configuration.api, tokenProvider: StaticAuthTokenProvider(token: nil))
        let account = DemoBotAccount(credentials: configuration.credentials, auth: RemoteAuthGateway(client: anonymous))
        let session = try await account.signIn()
        let tokens = DemoBotTokenProvider(session: session, account: account)
        let sharedTokens = CoalescingAuthTokenProvider(tokens)
        let client = APIClient(configuration: configuration.api, tokenProvider: sharedTokens)

        await progress(.publishingKeys)
        let keyStore = KeychainIdentityKeyStore(service: configuration.keychainService)
        let directory = RemoteKeyDirectoryGateway(client: client)
        do {
            try await DemoBotIdentity(keyStore: keyStore, directory: directory).publish()
        } catch {
            DemoBotLog.account.error("key publication failed: \(String(describing: type(of: error)), privacy: .public)")
            throw DemoBotError.keyPublishFailed
        }

        await progress(.connecting)
        let store: PersistenceStore
        do {
            store = try PersistenceStore.inMemory(accountId: session.user.id)
        } catch {
            DemoBotLog.account.error("in-memory store failed: \(String(describing: type(of: error)), privacy: .public)")
            throw DemoBotError.storeUnavailable
        }
        let realtime = WebSocketClient(configuration: configuration.api, tokenProvider: sharedTokens)
        let stack = MessagingStack(
            account: session.user,
            messages: DemoBotMessageRepository(base: store, memory: memory),
            conversations: store,
            contacts: store,
            outbox: store,
            replayGuard: store,
            crypto: CipherCryptoEngine(keyProvider: keyStore),
            keyDirectory: directory,
            conversationGateway: RemoteConversationGateway(client: client),
            realtime: realtime
        )
        return DemoBotClient(
            user: session.user,
            stack: stack,
            realtime: realtime,
            attachments: RemoteAttachmentGateway(client: client),
            tokens: tokens
        )
    }
}
#endif
