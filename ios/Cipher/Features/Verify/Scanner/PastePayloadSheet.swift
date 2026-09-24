import CipherDesign
import SwiftUI

/// Manual entry for a `cipher:verify?…` payload: the Simulator has no camera, some devices refuse
/// it, and a code sent over another channel is still worth checking against the pinned keys.
struct PastePayloadSheet: View {
    let contactName: String
    /// Returns `true` when the payload decoded; the sheet dismisses itself on success.
    let onSubmit: @MainActor (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var payload = ""
    @State private var showsRejection = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpacing.xl) {
                    Text(String(
                        localized: "verify.paste.explainer",
                        defaultValue: """
                            Ask \(contactName) to copy the code under \"Your code\" on their verification screen \
                            and send it to you, then paste it here.
                            """
                    ))
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    field
                    if showsRejection {
                        Label(
                            String(localized: "verify.paste.rejected", defaultValue: "That's not a Cipher verification code."),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(CipherTypography.caption)
                        .foregroundStyle(CipherColor.danger)
                        .transition(.opacity)
                    }
                    CipherButton(
                        String(localized: "verify.paste.submit", defaultValue: "Check this code"),
                        systemImage: "checkmark.shield",
                        action: submit
                    )
                    .disabled(payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(CipherSpacing.lg)
                .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: showsRejection)
            }
            .background(CipherColor.background.ignoresSafeArea())
            .navigationTitle(String(localized: "verify.paste.title", defaultValue: "Enter code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(CipherColor.accent)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            TextField(
                String(localized: "verify.paste.placeholder", defaultValue: "cipher:verify?v=1&uid=…"),
                text: $payload,
                axis: .vertical
            )
            .font(CipherTypography.monoSmall)
            .foregroundStyle(CipherColor.glyph)
            .lineLimit(3...8)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .focused($isFocused)
            .padding(CipherSpacing.md)
            .background(CipherColor.surfaceElevated, in: .rect(cornerRadius: CipherRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: CipherRadius.md)
                    .strokeBorder(isFocused ? CipherColor.accent : CipherColor.divider, lineWidth: 1)
            }
            .accessibilityLabel(String(localized: "verify.paste.field.a11y", defaultValue: "Verification code"))
            .onChange(of: payload) { showsRejection = false }

            Button {
                if let clipboard = UIPasteboard.general.string {
                    payload = clipboard
                }
            } label: {
                Label(
                    String(localized: "verify.paste.fromClipboard", defaultValue: "Paste from clipboard"),
                    systemImage: "doc.on.clipboard"
                )
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.accent)
            }
            .accessibilityHint(String(
                localized: "verify.paste.fromClipboard.hint",
                defaultValue: "Fills the field with the clipboard contents"
            ))
        }
    }

    private func submit() {
        if onSubmit(payload) {
            dismiss()
        } else {
            showsRejection = true
        }
    }
}

#Preview {
    PastePayloadSheet(contactName: "Bob") { code in code.hasPrefix("cipher:verify") }
}
