#if DEBUG
import CipherCore
import CipherDesign
import SwiftUI

/// One line under the Settings switch that says what Echo is doing, with a shortcut into the chat
/// once the conversation exists.
struct DemoBotStatusRow: View {
    let status: DemoBot.Status
    var conversationId: ConversationID?
    var problem: String?
    var onOpenChat: (@MainActor (ConversationID) -> Void)?

    var body: some View {
        HStack(spacing: CipherSpacing.md) {
            PresenceDot(online: status.isOnline, size: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(problem ?? detail)
                    .font(CipherTypography.caption)
                    .foregroundStyle(problem == nil ? CipherColor.textSecondary : CipherColor.warning)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let conversationId, let onOpenChat {
                Button {
                    onOpenChat(conversationId)
                } label: {
                    Text(String(localized: "demo.status.openChat", defaultValue: "Open"))
                        .font(CipherTypography.caption)
                }
                .buttonStyle(.cipherGhost)
                .accessibilityLabel(String(localized: "demo.status.openChat.a11y", defaultValue: "Open the chat with Echo"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title + ". " + (problem ?? detail))
    }

    private var title: String {
        switch status {
        case .stopped: String(localized: "demo.status.stopped", defaultValue: "Echo is off")
        case .signingIn: String(localized: "demo.status.signingIn", defaultValue: "Echo is signing in…")
        case .publishingKeys: String(localized: "demo.status.publishingKeys", defaultValue: "Publishing Echo's keys…")
        case .connecting: String(localized: "demo.status.connecting", defaultValue: "Echo is connecting…")
        case .online: String(localized: "demo.status.online", defaultValue: "Echo is online")
        case .reconnecting: String(localized: "demo.status.reconnecting", defaultValue: "Echo is reconnecting…")
        case .failed: String(localized: "demo.status.failed", defaultValue: "Echo couldn't start")
        }
    }

    private var detail: String {
        switch status {
        case .failed(let error):
            error.errorDescription ?? String(localized: "demo.status.failed.detail", defaultValue: "Check that the relay is running.")
        case .online(let user), .reconnecting(let user):
            String(localized: "demo.status.identity", defaultValue: "@\(user.username) · own keys, own store, same relay")
        case .stopped, .signingIn, .publishingKeys, .connecting:
            String(localized: "demo.status.explainer", defaultValue: "A second Cipher client in this app that answers you")
        }
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        DemoBotStatusRow(status: .online(Fixtures.echo), conversationId: ConversationID()) { _ in }
        DemoBotStatusRow(status: .publishingKeys)
        DemoBotStatusRow(status: .stopped)
        DemoBotStatusRow(status: .failed(.accountTaken))
        DemoBotStatusRow(status: .online(Fixtures.echo), problem: "This contact has not published encryption keys yet.")
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
#endif
