import CipherCore
import CipherDesign
import SwiftUI

/// Navigation-bar centrepiece: avatar inside the trust ring, name with shield, and a presence line
/// that swaps to the typing indicator. Tapping the ring opens verification because the ring is the
/// thing that says "you have not checked this person yet".
struct ChatHeaderView: View {
    let state: ChatHeaderState
    let onTrustTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: CipherSpacing.sm) {
            Button(action: onTrustTap) {
                TrustRing(score: state.trust.ringScore, segments: 8, size: 38) {
                    InitialsAvatar(name: state.name, seed: state.seed, size: 30) {
                        PresenceDot(online: state.isOnline, size: 9)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "chat.header.trustRing.a11y", defaultValue: "Trust ring, opens verification"))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: CipherSpacing.xs) {
                    Text(state.name)
                        .font(.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                        .lineLimit(1)
                    ShieldBadge(state: state.trust.shieldState, size: 14)
                }
                subtitle
                    .frame(height: 14)
            }
        }
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: state.isTyping)
        .accessibilityElement(children: .combine)
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
                Menu {
                    Button {
                        onDisappearing(nil)
                    } label: {
                        timerOption(String(localized: "chat.header.disappearing.off", defaultValue: "Off"),
                                    isSelected: state.disappearingTimer == nil)
                    }
                    ForEach(ComposerOptions.disappearingPresets, id: \.self) { preset in
                        Button {
                            onDisappearing(preset)
                        } label: {
                            timerOption(CountdownRing.label(forRemaining: preset), isSelected: state.disappearingTimer == preset)
                        }
                    }
                } label: {
                    Label(String(localized: "chat.header.menu.disappearing", defaultValue: "Disappearing messages"), systemImage: "timer")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(String(localized: "chat.header.menu.a11y", defaultValue: "Conversation options"))
        }
    }

    @ViewBuilder
    private func timerOption(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
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
