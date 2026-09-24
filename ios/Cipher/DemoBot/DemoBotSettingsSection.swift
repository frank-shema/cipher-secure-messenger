#if DEBUG
import CipherCore
import CipherDesign
import SwiftUI

/// The Settings "Developer" card: the Echo switch with a live status line underneath and, once the
/// conversation exists, a shortcut into it. Replaces the placeholder toggle in `SettingsView`; the
/// switch writes the same `AppPreferences` flag, so nothing else in Settings has to change.
struct DemoBotSettingsSection: View {
    let controller: DemoBotController
    /// Navigates to the chat with Echo; nil hides the shortcut.
    var onOpenChat: (@MainActor (ConversationID) -> Void)?

    @State private var isEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(controller: DemoBotController, onOpenChat: (@MainActor (ConversationID) -> Void)? = nil) {
        self.controller = controller
        self.onOpenChat = onOpenChat
        _isEnabled = State(initialValue: controller.isEnabled)
    }

    var body: some View {
        SectionCard(title: String(localized: "settings.section.developer", defaultValue: "Developer")) {
            Toggle(isOn: $isEnabled) {
                SettingsRow(
                    icon: "waveform.path.ecg",
                    title: String(localized: "settings.demo.title", defaultValue: "Demo companion (Echo)"),
                    detail: String(localized: "settings.demo.detail", defaultValue: "A local bot that replies to you"),
                    showsChevron: false
                )
            }
            .tint(CipherColor.accent)
            .accessibilityLabel(String(localized: "settings.demo.title", defaultValue: "Demo companion (Echo)"))
            .onChange(of: isEnabled) { _, enabled in
                controller.isEnabled = enabled
            }
            if isEnabled {
                DemoBotStatusRow(
                    status: controller.status,
                    conversationId: controller.conversationId,
                    problem: controller.conversationProblem,
                    onOpenChat: onOpenChat
                )
                .padding(.top, CipherSpacing.md)
                .transition(.opacity)
            }
            Text(footer)
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, CipherSpacing.md)
        }
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: isEnabled)
    }

    private var footer: String {
        String(
            localized: "demo.settings.footer",
            defaultValue: "Echo is a second Cipher client inside this debug build, with its own keys and store. "
                + "It talks to the same relay you do and sees only ciphertext until it decrypts on its side."
        )
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview.demoBot") ?? .standard
    let controller = DemoBotWiring.makeController(endpoints: .localhost, defaults: defaults)
    ScrollView {
        DemoBotSettingsSection(controller: controller) { _ in }
            .padding(CipherSpacing.lg)
    }
    .background(CipherColor.background)
}
#endif
