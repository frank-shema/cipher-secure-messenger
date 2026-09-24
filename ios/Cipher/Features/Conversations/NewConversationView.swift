import CipherCore
import CipherDesign
import SwiftUI

/// Username entry that resolves a contact, pins their keys and opens the thread. Validation mirrors
/// the relay's rule (`^[a-z0-9_]{3,32}$`) so a typo is caught before a round trip.
struct NewConversationView: View {
    let start: any ConversationStarting
    let onOpen: @MainActor (ConversationID) -> Void

    @State private var username = ""
    @State private var isStarting = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var normalized: String { username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private var isValid: Bool { normalized.wholeMatch(of: /[a-z0-9_]{3,32}/) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.xl) {
            VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                Text(String(localized: "newChat.heading", defaultValue: "Who do you want to reach?"))
                    .font(CipherTypography.title)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(String(
                    localized: "newChat.explainer",
                    defaultValue: "Their public keys are fetched and pinned on this device before the first message is sealed."
                ))
                    .font(.subheadline)
                    .foregroundStyle(CipherColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                CipherTextField(title: String(localized: "newChat.username.title", defaultValue: "Username"), text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.go)
                    .focused($isFocused)
                    .onSubmit(startConversation)
                    .accessibilityLabel(String(localized: "newChat.username.a11y", defaultValue: "Contact username"))
                if !username.isEmpty, !isValid {
                    Label(String(localized: "newChat.username.invalid", defaultValue: "3–32 lowercase letters, digits or underscores"),
                          systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(CipherColor.warning)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .font(.caption)
                        .foregroundStyle(CipherColor.danger)
                        .accessibilityLabel(errorMessage)
                }
            }

            Button(action: startConversation) {
                HStack(spacing: CipherSpacing.sm) {
                    if isStarting {
                        ProgressView().tint(CipherColor.bubbleOutgoingText)
                    } else {
                        Image(systemName: "lock.open.rotation")
                    }
                    Text(isStarting
                         ? String(localized: "newChat.action.starting", defaultValue: "Pinning keys…")
                         : String(localized: "newChat.action.start", defaultValue: "Start encrypted chat"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.cipherPrimary)
            .disabled(!isValid || isStarting)
            .accessibilityLabel(String(localized: "newChat.action.start", defaultValue: "Start encrypted chat"))

            Spacer()
        }
        .padding(CipherSpacing.xl)
        .background(CipherColor.background.ignoresSafeArea())
        .navigationTitle(String(localized: "newChat.title", defaultValue: "New chat"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
            }
        }
        .onAppear { isFocused = true }
    }

    private func startConversation() {
        guard isValid, !isStarting else { return }
        isStarting = true
        errorMessage = nil
        let username = normalized
        Task {
            defer { isStarting = false }
            do {
                let conversation = try await start.execute(username: username)
                ChatLog.conversations.info("started conversation=\(conversation.id.description, privacy: .public)")
                onOpen(conversation.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewConversationView(start: PreviewMessaging.bundle().list.start) { _ in }
    }
}
