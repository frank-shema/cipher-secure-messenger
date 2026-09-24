import CipherCore
import Foundation
import Observation

/// The inbox: a live list of conversations plus search, swipe actions and pull-to-refresh. Search
/// matches the contact and the decrypted preview because the preview is the only content the
/// person can see without opening the thread.
@MainActor
@Observable
final class ConversationListViewModel {
    private(set) var conversations: [Conversation] = []
    private(set) var isLoaded = false
    private(set) var isRefreshing = false
    var searchText = ""
    var errorMessage: String?

    private let deps: ConversationListDependencies
    private var observation: Task<Void, Never>?

    init(dependencies: ConversationListDependencies) {
        self.deps = dependencies
    }

    var now: Date { deps.now() }

    var filtered: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            conversation.contact.user.displayName.localizedCaseInsensitiveContains(query)
                || conversation.contact.user.username.localizedCaseInsensitiveContains(query)
                || MessageFormatting.preview(for: conversation.lastMessage).localizedCaseInsensitiveContains(query)
        }
    }

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func start() {
        guard observation == nil else { return }
        observation = Task { [weak self] in
            guard let self else { return }
            let stream = await deps.observeConversations.execute()
            for await batch in stream {
                guard !Task.isCancelled else { return }
                conversations = batch.sorted { $0.updatedAt > $1.updatedAt }
                isLoaded = true
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }

    /// Syncs every conversation; one failure does not stop the others because the person pulled to
    /// see whatever is reachable, not to be told about the one that is not.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var failures = 0
        for conversation in conversations {
            do {
                _ = try await deps.sync.execute(conversationId: conversation.id)
            } catch {
                failures += 1
                ChatLog.conversations.error("sync failed conversation=\(conversation.id.description, privacy: .public)")
            }
        }
        if failures > 0 {
            errorMessage = String(localized: "conversations.error.partialSync",
                                  defaultValue: "\(failures) conversation(s) could not be refreshed.")
        }
    }

    func markRead(_ id: ConversationID) {
        Task {
            do {
                _ = try await deps.markRead.execute(conversationId: id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Local only: the relay keeps nothing readable, and the other participant keeps their copy.
    func delete(_ id: ConversationID) {
        Task {
            do {
                try await deps.conversations.delete(id: id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
