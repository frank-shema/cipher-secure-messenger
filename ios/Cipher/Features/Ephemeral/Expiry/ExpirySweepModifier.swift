import CipherCore
import CipherDesign
import SwiftUI

/// Tells the `ExpiryScheduler` when a chat is on screen (fast cadence) and hands each sweep's
/// deletions to the caller, so a ViewModel can drop rows it cached outside the live window.
struct ExpirySweepModifier: ViewModifier {
    let scheduler: ExpiryScheduler
    let conversationId: ConversationID
    let onDeleted: @MainActor ([MessageID]) -> Void

    func body(content: Content) -> some View {
        content
            .task {
                await scheduler.chatDidAppear(conversationId)
                let stream = await scheduler.deletions
                for await deleted in stream {
                    guard !Task.isCancelled else { break }
                    onDeleted(deleted)
                }
            }
            .onDisappear {
                Task { await scheduler.chatDidDisappear(conversationId) }
            }
    }
}

extension View {
    /// Registers this chat with the expiry scheduler for as long as it is visible.
    func expirySweeps(
        _ scheduler: ExpiryScheduler,
        conversationId: ConversationID,
        onDeleted: @escaping @MainActor ([MessageID]) -> Void = { _ in }
    ) -> some View {
        modifier(ExpirySweepModifier(scheduler: scheduler, conversationId: conversationId, onDeleted: onDeleted))
    }
}

#Preview {
    struct Demo: View {
        let scheduler = ExpiryScheduler(deleter: PreviewExpiredMessageDeleter(expiringEvery: 3), chatInterval: .seconds(1))
        @State private var deleted: [MessageID] = []

        var body: some View {
            VStack(spacing: CipherSpacing.md) {
                Text("Sweeps every second while visible")
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text("\(deleted.count) deleted so far")
                    .font(CipherTypography.body.monospacedDigit())
                    .foregroundStyle(CipherColor.textSecondary)
            }
            .padding(CipherSpacing.xl)
            .background(CipherColor.background)
            .expirySweeps(scheduler, conversationId: MessagingFixtures.bobConversationId) { deleted.append(contentsOf: $0) }
            .task { await scheduler.start() }
        }
    }
    return Demo()
}
