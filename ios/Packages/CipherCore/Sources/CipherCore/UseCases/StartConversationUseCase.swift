import Foundation

/// Looks a username up, pins their keys, and creates (or resolves) the 1:1 conversation.
public struct StartConversationUseCase: Sendable {
    private let currentUserId: UserID
    private let keyDirectory: any KeyDirectoryGateway
    private let conversationGateway: any ConversationGateway
    private let contacts: any ContactRepository
    private let conversations: any ConversationRepository
    private let clock: any Clock

    public init(
        currentUserId: UserID,
        keyDirectory: any KeyDirectoryGateway,
        conversationGateway: any ConversationGateway,
        contacts: any ContactRepository,
        conversations: any ConversationRepository,
        clock: any Clock = SystemClock()
    ) {
        self.currentUserId = currentUserId
        self.keyDirectory = keyDirectory
        self.conversationGateway = conversationGateway
        self.contacts = contacts
        self.conversations = conversations
        self.clock = clock
    }

    /// Keys are pinned BEFORE the conversation is created so a conversation can never exist locally
    /// without the material needed to seal its first message.
    public func execute(username: String) async throws -> Conversation {
        let remote = try await keyDirectory.lookup(username: username)
        guard remote.user.id != currentUserId else {
            throw CipherCoreError.cannotMessageSelf
        }
        let contact = try await ContactPinning.pin(remote, into: contacts, now: clock.now())
        let remoteConversation = try await conversationGateway.createOrGet(participantId: remote.user.id)
        if var existing = try await conversations.fetch(id: remoteConversation.id) {
            existing.contact = contact
            try await conversations.upsert(existing)
            return existing
        }
        let conversation = Conversation(
            id: remoteConversation.id,
            contact: contact,
            lastMessage: nil,
            unreadCount: 0,
            updatedAt: remoteConversation.lastMessageAt ?? remoteConversation.createdAt,
            disappearingTimer: nil
        )
        try await conversations.upsert(conversation)
        CoreLog.useCases.info("started conversation \(conversation.id.description, privacy: .public)")
        return conversation
    }
}
