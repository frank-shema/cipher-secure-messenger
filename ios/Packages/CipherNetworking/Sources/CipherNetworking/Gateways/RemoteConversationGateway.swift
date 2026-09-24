import CipherCore
import Foundation

/// `ConversationGateway` over `/conversations/*`.
public struct RemoteConversationGateway: ConversationGateway {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func createOrGet(participantId: UserID) async throws -> RemoteConversation {
        let conversation = try await client.send(CreateConversationEndpoint(participantId: participantId))
        NetLog.api.info("resolved conversation \(conversation.id.description, privacy: .public)")
        return conversation.toDomain()
    }

    public func list() async throws -> [RemoteConversation] {
        let list = try await client.send(ListConversationsEndpoint())
        NetLog.api.debug("listed \(list.conversations.count, privacy: .public) conversations")
        return list.toDomain()
    }

    public func fetchMessages(conversationId: ConversationID, before: Date?, limit: Int) async throws -> MessagePage {
        let endpoint = FetchMessagesEndpoint(
            conversationId: conversationId,
            before: before?.epochMillis,
            limit: limit
        )
        let page = try await client.send(endpoint)
        NetLog.api.debug(
            "fetched \(page.items.count, privacy: .public) messages for \(conversationId.description, privacy: .public)"
        )
        return page.toDomain()
    }

    public func send(_ envelope: Envelope) async throws -> MessageAck {
        let ack = try await client.send(SendMessageEndpoint(envelope: envelope))
        NetLog.api.debug("message \(ack.id.description, privacy: .public) acked as \(ack.status.rawValue, privacy: .public)")
        return ack.toDomain()
    }
}
