import CipherCore
import CipherDesign
import SwiftUI

/// Navigation-bar centrepiece: avatar inside the trust ring, name with shield, the active timer
/// badge and a presence line that swaps to the typing indicator. Tapping the ring opens "Why this
/// chat is secure", because the ring is the thing that says how much has been checked.
struct ChatHeaderView: View {
    let state: ChatHeaderState
    let onTrustTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: CipherSpacing.sm) {
            TrustRingAvatar(name: state.name, seed: state.seed, score: state.trustScore, isOnline: state.isOnline, onTap: onTrustTap)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: CipherSpacing.xs) {
                    Text(state.name)
                        .font(.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                        .lineLimit(1)
                    ShieldBadge(state: state.trust.shieldState, size: 14)
                    DisappearingTimerBadge(timer: DisappearingTimer(seconds: state.disappearingTimer))
                }
                subtitle
                    .frame(height: 14)
            }
        }
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: state.isTyping)
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: state.trustScore)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var subtitle: some View {
        if state.isTyping {
            HStack(spacing: CipherSpacing.xs) {
                TypingIndicator().scaleEffect(0.7)
                Text(String(localized: "chat.header.typing", defaultValue: "typing…"))
            }
            .font(.caption)
            .foregroundStyle(CipherColor.accent)
            .transition(.opacity)
        } else {
            Text(state.subtitle)
                .font(.caption)
                .foregroundStyle(state.isOnline ? CipherColor.success : CipherColor.textSecondary)
                .lineLimit(1)
                .transition(.opacity)
        }
    }
}

/// Trailing toolbar menu: verify, Server's-Eye toggle and the disappearing-message timer.
struct ChatHeaderMenu: View {
    let state: ChatHeaderState
    let isServersEyeOn: Bool
    let onVerify: () -> Void
    let onToggleServersEye: () -> Void
    let onDisappearing: (TimeInterval?) -> Void

    var body: some View {
        HStack(spacing: CipherSpacing.md) {
            Button(action: onToggleServersEye) {
                Image(systemName: isServersEyeOn ? "eye.fill" : "eye")
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(isServersEyeOn ? CipherColor.accentSecondary : CipherColor.accent)
            .accessibilityLabel(String(localized: "chat.header.serversEye.a11y", defaultValue: "Server's-Eye view"))
            .accessibilityValue(isServersEyeOn
                                ? String(localized: "common.on", defaultValue: "On")
                                : String(localized: "common.off", defaultValue: "Off"))

            Menu {
                Button(action: onVerify) {
                    Label(state.trust.isVerified
                          ? String(localized: "chat.header.menu.reverify", defaultValue: "Re-verify safety code")
                          : String(localized: "chat.header.menu.verify", defaultValue: "Verify safety code"),
                          systemImage: "checkmark.shield")
                }
                DisappearingTimerMenu(seconds: state.disappearingTimer) { onDisappearing($0.seconds) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(String(localized: "chat.header.menu.a11y", defaultValue: "Conversation options"))
        }
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel()
    NavigationStack {
        Color.clear
            .background(CipherColor.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ChatHeaderView(state: viewModel.header) {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ChatHeaderMenu(state: viewModel.header, isServersEyeOn: false,
                                   onVerify: {}, onToggleServersEye: {}, onDisappearing: { _ in })
                }
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}
