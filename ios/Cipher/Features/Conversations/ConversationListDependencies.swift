import CipherCore
import Foundation

/// Everything the inbox needs, gathered so the composition root builds it once and previews swap in
/// the in-memory fakes from `Data/Mocks/Messaging`.
struct ConversationListDependencies: Sendable {
    var observeConversations: any ConversationsObserving
    var markRead: any ConversationReadMarking
    var sync: any ConversationSyncing
    var start: any ConversationStarting
    var conversations: any ConversationRepository
    /// Injected time source so relative timestamps in previews are stable.
    var now: @Sendable () -> Date

    init(
        observeConversations: any ConversationsObserving,
        markRead: any ConversationReadMarking,
        sync: any ConversationSyncing,
        start: any ConversationStarting,
        conversations: any ConversationRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.observeConversations = observeConversations
        self.markRead = markRead
        self.sync = sync
        self.start = start
        self.conversations = conversations
        self.now = now
    }
}

/// Navigation the inbox asks its host to perform.
struct ConversationListRoutes {
    var onOpenConversation: @MainActor (ConversationID) -> Void
    var onNewConversation: @MainActor () -> Void
    var onSettings: @MainActor () -> Void

    init(
        onOpenConversation: @escaping @MainActor (ConversationID) -> Void = { _ in },
        onNewConversation: @escaping @MainActor () -> Void = {},
        onSettings: @escaping @MainActor () -> Void = {}
    ) {
        self.onOpenConversation = onOpenConversation
        self.onNewConversation = onNewConversation
        self.onSettings = onSettings
    }
}
