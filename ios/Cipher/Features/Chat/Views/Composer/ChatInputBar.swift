import CipherCore
import CipherDesign
import SwiftUI

/// The composer: attachment menu, per-message mode toggles, a growing text field and the send
/// button, with `ComposerAccessories` stacked above. Mode toggles live here rather than in a menu
/// because their state must be visible at the moment of sending.
struct ChatInputBar: View {
    @Bindable var viewModel: ChatViewModel

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var modeSymbol: String? {
        if viewModel.composer.isTimeCapsule { return "envelope.badge.clock" }
        if viewModel.composer.whisper { return "ear" }
        if viewModel.composer.viewOnce { return "eye" }
        return nil
    }

    var body: some View {
        VStack(spacing: CipherSpacing.sm) {
            ComposerAccessories(viewModel: viewModel)
            HStack(alignment: .bottom, spacing: CipherSpacing.sm) {
                attachmentMenu
                toggles
                field
                SendButton(isEnabled: viewModel.canSend, modeSymbol: modeSymbol, action: viewModel.send)
            }
        }
        .padding(.horizontal, CipherSpacing.md)
        .padding(.vertical, CipherSpacing.sm)
        .background(.bar)
        .overlay(alignment: .top) { Rectangle().fill(CipherColor.divider).frame(height: 0.5) }
        .sheet(isPresented: $viewModel.isTimeCapsulePickerPresented) {
            TimeCapsulePickerSheet(unlockAt: $viewModel.composer.unlockAt, now: viewModel.now)
        }
    }

    private var field: some View {
        TextField(
            String(localized: "chat.composer.placeholder", defaultValue: "Encrypted message"),
            text: $viewModel.draft,
            axis: .vertical
        )
        .lineLimit(1...6)
        .font(CipherTypography.body)
        .foregroundStyle(CipherColor.textPrimary)
        .padding(.horizontal, CipherSpacing.md)
        .padding(.vertical, CipherSpacing.sm)
        .background(CipherColor.surface, in: RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.lg, style: .continuous)
                .strokeBorder(viewModel.composer.isAnyEnabled ? CipherColor.accent.opacity(0.6) : CipherColor.divider)
        )
        .focused($isFocused)
        .submitLabel(.return)
        .accessibilityLabel(String(localized: "chat.composer.field.a11y", defaultValue: "Message"))
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: viewModel.composer.isAnyEnabled)
    }

    private var attachmentMenu: some View {
        Menu {
            Button(action: viewModel.onPickPhoto) {
                Label(String(localized: "chat.composer.attach.photo", defaultValue: "Photo"), systemImage: "photo.on.rectangle")
            }
            Button(action: viewModel.onPickFile) {
                Label(String(localized: "chat.composer.attach.file", defaultValue: "File"), systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CipherColor.accent)
        }
        .padding(.bottom, 3)
        .accessibilityLabel(String(localized: "chat.composer.attach.a11y", defaultValue: "Attach"))
    }

    private var toggles: some View {
        HStack(spacing: CipherSpacing.xs) {
            modeToggle(symbol: "ear", isOn: viewModel.composer.whisper,
                       label: String(localized: "chat.composer.whisper.a11y", defaultValue: "Whisper")) {
                viewModel.composer.whisper.toggle()
            }
            if viewModel.stagedAttachment?.isImage == true {
                modeToggle(symbol: "eye", isOn: viewModel.composer.viewOnce,
                           label: String(localized: "chat.composer.viewOnce.a11y", defaultValue: "View once")) {
                    viewModel.composer.viewOnce.toggle()
                }
            }
            modeToggle(symbol: "envelope.badge.clock", isOn: viewModel.composer.isTimeCapsule,
                       label: String(localized: "chat.composer.capsule.a11y", defaultValue: "Time Capsule")) {
                viewModel.isTimeCapsulePickerPresented = true
            }
        }
        .padding(.bottom, 5)
        .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: viewModel.stagedAttachment?.isImage)
    }

    private func modeToggle(symbol: String, isOn: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isOn ? "\(symbol).fill" : symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isOn ? CipherColor.bubbleOutgoingText : CipherColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(isOn ? AnyShapeStyle(CipherGradient.primaryAction) : AnyShapeStyle(.clear), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn
                            ? String(localized: "common.on", defaultValue: "On")
                            : String(localized: "common.off", defaultValue: "Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    let viewModel = PreviewMessaging.chatViewModel()
    VStack {
        Spacer()
        ChatInputBar(viewModel: viewModel)
    }
    .background(CipherColor.background)
    .task { viewModel.draft = "Sealing this one with a whisper" }
}
