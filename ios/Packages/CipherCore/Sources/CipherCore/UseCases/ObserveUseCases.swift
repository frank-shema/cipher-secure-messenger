import Foundation

/// Live message list of one conversation, for the chat screen.
public struct ObserveConversationUseCase: Sendable {
    private let messages: any MessageRepository

    public init(messages: any MessageRepository) {
        self.messages = messages
    }

    public func execute(conversationId: ConversationID) async -> AsyncStream<[Message]> {
        await messages.observe(conversationId: conversationId)
    }
}

/// Live conversation list, for the inbox.
public struct ObserveConversationsUseCase: Sendable {
    private let conversations: any ConversationRepository

    public init(conversations: any ConversationRepository) {
        self.conversations = conversations
    }

    public func execute() async -> AsyncStream<[Conversation]> {
        await conversations.observeAll()
    }
}
