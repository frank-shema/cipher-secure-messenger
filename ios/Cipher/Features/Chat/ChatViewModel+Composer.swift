import CipherCore
import CipherDesign
import Foundation

/// The composer half of the ViewModel: draft scanning, the sensitive-content suggestion and sending.
extension ChatViewModel {
    func draftDidChange() {
        typingDebouncer.draftChanged(isEmpty: draft.isEmpty)
        sensitiveTask?.cancel()
        let text = draft
        guard !text.isEmpty else {
            sensitiveFindingDidChange(nil)
            dismissedSensitiveKind = nil
            return
        }
        sensitiveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            let kind = await deps.sensitiveDetector.detect(in: text)
            guard !Task.isCancelled else { return }
            sensitiveFindingDidChange(kind == dismissedSensitiveKind ? nil : kind)
        }
    }

    /// Accepting the guard's suggestion applies its flags: view-once, a one-minute auto-delete after
    /// reading, and, for text, a whisper so the secret is never in the clear on the other screen.
    func acceptSensitiveSuggestion() {
        guard let kind = sensitiveFinding else { return }
        let flags = SensitiveSuggestion(kind: kind, confidence: 1).apply(to: composer.flags(conversationTimer: nil))
        composer.viewOnce = flags.viewOnce
        composer.suggestedDisappearAfter = flags.disappearAfter
        if stagedAttachment == nil { composer.whisper = true }
        sensitiveFindingDidChange(nil)
        haptics.play(.lock)
    }

    func dismissSensitiveSuggestion() {
        dismissedSensitiveKind = sensitiveFinding
        sensitiveFindingDidChange(nil)
    }

    /// Flags and the relay-visible expiry are decided together by `ExpiryPolicyApplier`, so the
    /// instant on the envelope can never disagree with the timer inside the ciphertext.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let staged = stagedAttachment
        guard !text.isEmpty || staged != nil else {
            errorMessage = ChatError.nothingToSend.localizedDescription
            return
        }
        let timer = conversation.disappearingTimer
        let outcome = ExpiryPolicyApplier().apply(flags: composer.flags(conversationTimer: timer), conversationTimer: timer, sentAt: now)
        let replyTo = replyingTo?.id
        resetComposer()
        Task { await deliver(text: text, staged: staged, flags: outcome.flags, replyTo: replyTo, expiresAt: outcome.expiresAt) }
    }

    private func deliver(text: String, staged: StagedAttachment?, flags: MessageFlags, replyTo: MessageID?, expiresAt: Date?) async {
        do {
            if let staged {
                guard let attachments = deps.attachments else { throw ChatError.attachmentsUnavailable }
                let caption = text.isEmpty ? nil : text
                let request = AttachmentSendRequest(staged: staged, caption: caption, flags: flags, replyTo: replyTo,
                                                    conversationId: conversationId, expiresAt: expiresAt)
                _ = try await attachments.send(request)
            } else {
                let payload = MessagePayload.text(text, flags: flags, replyTo: replyTo)
                _ = try await deps.sender.execute(conversationId: conversationId, payload: payload, expiresAt: expiresAt)
            }
            haptics.play(.sent)
        } catch {
            let failure = String(describing: type(of: error))
            let id = conversationId.description
            ChatLog.chat.error("send failed conversation=\(id, privacy: .public) error=\(failure, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func resetComposer() {
        draft = ""
        replyingTo = nil
        composer = ComposerOptions()
        stagedAttachment = nil
        sensitiveFindingDidChange(nil)
        dismissedSensitiveKind = nil
        typingDebouncer.stop()
    }
}
