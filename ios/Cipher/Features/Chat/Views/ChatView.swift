import CipherCore
import CipherDesign
import SwiftUI

/// The conversation screen: header in the navigation bar, transcript, composer, and the sheets the
/// ViewModel drives. Lifecycle is tied to appearance so streams stop when the screen is gone.
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.header.trust.needsAttention {
                KeyChangeWarningBanner(contactName: viewModel.header.name, onReview: viewModel.verify)
                    .padding(.horizontal, CipherSpacing.md)
                    .padding(.top, CipherSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            MessageList(viewModel: viewModel)
            ChatInputBar(viewModel: viewModel)
        }
        .background(CipherColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeaderView(state: viewModel.header, onTrustTap: viewModel.verify)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ChatHeaderMenu(
                    state: viewModel.header,
                    isServersEyeOn: viewModel.isServersEyePresented,
                    onVerify: viewModel.verify,
                    onToggleServersEye: viewModel.toggleServersEye,
                    onDisappearing: viewModel.setDisappearingTimer
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.isServersEyePresented) {
            ServersEyeView(
                messages: viewModel.messages,
                contactName: viewModel.header.name,
                envelopes: viewModel.deps.envelopes
            )
        }
        .alert(
            String(localized: "chat.error.title", defaultValue: "Could not complete that"),
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } }),
            actions: { Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: viewModel.header.trust.needsAttention)
        .task {
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
    }
}

#Preview("Bob") {
    NavigationStack {
        ChatView(viewModel: PreviewMessaging.chatViewModel())
    }
}

#Preview("Key changed") {
    let bundle = PreviewMessaging.bundle()
    let conversation = bundle.conversations.first { $0.contact.trust.needsAttention } ?? PreviewMessaging.sampleConversation
    NavigationStack {
        ChatView(viewModel: ChatViewModel(conversation: conversation, dependencies: bundle.chat))
    }
}
