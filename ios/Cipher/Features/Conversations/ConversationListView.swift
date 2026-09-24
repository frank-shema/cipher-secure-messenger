import CipherCore
import CipherDesign
import SwiftUI

/// The inbox screen. Rows open threads; swiping marks read or deletes locally; pulling syncs every
/// conversation with the relay. Navigation is delegated to `ConversationListRoutes` so the host
/// decides how each destination is presented.
struct ConversationListView: View {
    @Bindable var viewModel: ConversationListViewModel
    let routes: ConversationListRoutes

    var body: some View {
        Group {
            if !viewModel.isLoaded {
                loadingState
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(CipherColor.background)
        .navigationTitle(String(localized: "conversations.title", defaultValue: "Chats"))
        .toolbar { toolbar }
        .searchable(text: $viewModel.searchText, prompt: String(localized: "conversations.search.prompt", defaultValue: "Search chats"))
        .refreshable { await viewModel.refresh() }
        .alert(
            String(localized: "conversations.error.title", defaultValue: "Something went wrong"),
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } }),
            actions: { Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
        .task {
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
    }

    private var list: some View {
        List {
            ForEach(viewModel.filtered) { conversation in
                Button {
                    routes.onOpenConversation(conversation.id)
                } label: {
                    ConversationRow(conversation: conversation, now: viewModel.now)
                }
                .buttonStyle(.plain)
                .listRowBackground(CipherColor.background)
                .listRowSeparatorTint(CipherColor.divider)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if conversation.unreadCount > 0 {
                        Button {
                            viewModel.markRead(conversation.id)
                        } label: {
                            Label(String(localized: "conversations.action.markRead", defaultValue: "Mark read"),
                                  systemImage: "envelope.open")
                        }
                        .tint(CipherColor.accent)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.delete(conversation.id)
                    } label: {
                        Label(String(localized: "conversations.action.delete", defaultValue: "Delete"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if viewModel.filtered.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String(localized: "conversations.search.empty.title", defaultValue: "No matches"),
                    message: String(localized: "conversations.search.empty.message",
                                    defaultValue: "Nothing in your chats matches that search.")
                )
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "lock.bubble",
            title: String(localized: "conversations.empty.title", defaultValue: "No chats yet"),
            message: String(localized: "conversations.empty.message",
                            defaultValue: "Start a conversation. Only the two of you will ever be able to read it."),
            action: EmptyStateView.Action(title: String(localized: "conversations.empty.action", defaultValue: "New chat")) {
                routes.onNewConversation()
            }
        )
    }

    private var loadingState: some View {
        VStack(spacing: CipherSpacing.md) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: CipherSpacing.md) {
                    SkeletonView(cornerRadius: 26).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                        SkeletonView().frame(height: 14).frame(maxWidth: 160)
                        SkeletonView().frame(height: 12)
                    }
                }
            }
            Spacer()
        }
        .padding(CipherSpacing.lg)
        .accessibilityLabel(String(localized: "conversations.loading", defaultValue: "Loading chats"))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: routes.onSettings) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "conversations.toolbar.settings", defaultValue: "Settings"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: routes.onNewConversation) {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(String(localized: "conversations.toolbar.newChat", defaultValue: "New chat"))
        }
    }
}

#Preview("Inbox") {
    NavigationStack {
        ConversationListView(viewModel: PreviewMessaging.conversationListViewModel(), routes: ConversationListRoutes())
    }
}

#Preview("Empty") {
    NavigationStack {
        ConversationListView(
            viewModel: ConversationListViewModel(dependencies: PreviewMessaging.bundle(seeded: false).list),
            routes: ConversationListRoutes()
        )
    }
}
