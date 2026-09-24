import CipherCore
import CipherDesign
import SwiftUI

/// The scrolling transcript. Auto-scrolls on your own sends and on incoming messages only while the
/// bottom is already in view; otherwise a pill counts what arrived so reading is never interrupted.
/// Reaching the top pages older history in.
struct MessageList: View {
    let viewModel: ChatViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isNearBottom = true
    @State private var unseenCount = 0

    private let bottomAnchor = "chat.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    topSentinel
                    ForEach(viewModel.sections) { section in
                        DaySeparator(date: section.date)
                            .padding(.vertical, CipherSpacing.md)
                        ForEach(section.groups) { group in
                            ForEach(group.items) { item in
                                MessageRow(item: item, viewModel: viewModel)
                            }
                        }
                    }
                    bottomSentinel
                }
                .padding(.bottom, CipherSpacing.sm)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .background(CipherColor.background)
            .onChange(of: viewModel.messages.last?.id) { _, newestId in
                handleNewest(newestId, proxy: proxy)
            }
            .overlay(alignment: .bottom) {
                if !isNearBottom, unseenCount > 0 {
                    newMessagesPill(proxy: proxy)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: unseenCount)
        }
    }

    @ViewBuilder
    private var topSentinel: some View {
        if viewModel.hasOlder, !viewModel.messages.isEmpty {
            HStack {
                Spacer()
                if viewModel.isLoadingOlder {
                    ProgressView().tint(CipherColor.accent)
                } else {
                    Text(String(localized: "chat.list.loadOlder", defaultValue: "Older messages"))
                        .font(.caption)
                        .foregroundStyle(CipherColor.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, CipherSpacing.md)
            .onAppear { viewModel.loadOlder() }
            .accessibilityLabel(String(localized: "chat.list.loadOlder.a11y", defaultValue: "Loading older messages"))
        }
    }

    private var bottomSentinel: some View {
        Color.clear
            .frame(height: 1)
            .id(bottomAnchor)
            .onAppear {
                isNearBottom = true
                unseenCount = 0
            }
            .onDisappear { isNearBottom = false }
    }

    private func handleNewest(_ newestId: MessageID?, proxy: ScrollViewProxy) {
        guard let newestId, let newest = viewModel.messagesById[newestId] else { return }
        if newest.direction == .outgoing || isNearBottom {
            withAnimation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } else {
            unseenCount += 1
        }
    }

    private func newMessagesPill(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } label: {
            Label(
                String(localized: "chat.list.newMessages", defaultValue: "\(unseenCount) new"),
                systemImage: "arrow.down"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(CipherColor.bubbleOutgoingText)
            .padding(.horizontal, CipherSpacing.md)
            .padding(.vertical, CipherSpacing.sm)
            .background(CipherGradient.primaryAction, in: Capsule())
            .cipherShadow(.medium)
        }
        .buttonStyle(.plain)
        .padding(.bottom, CipherSpacing.md)
        .accessibilityLabel(String(localized: "chat.list.newMessages.a11y", defaultValue: "\(unseenCount) new messages, scroll to bottom"))
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel()
    MessageList(viewModel: viewModel)
        .task { viewModel.start() }
}
