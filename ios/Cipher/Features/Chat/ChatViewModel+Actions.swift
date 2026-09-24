import CipherCore
import CipherDesign
import Foundation

/// Per-message actions and paging. Split from the core ViewModel so the lifecycle and composer logic
/// stay readable; everything here still goes through `ChatDependencies`.
extension ChatViewModel {
    /// The six reactions offered in the context menu. Kept short so the palette fits one row.
    static let quickReactions = ["❤️", "👍", "😂", "😮", "😢", "🔥"]

    // MARK: Paging & read state

    func loadOlder() {
        guard hasOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        Task {
            defer { isLoadingOlder = false }
            do {
                let page = try await deps.messages.fetch(conversationId: conversationId, limit: pageSize, before: oldest.effectiveTimestamp)
                let unknown = page.filter { candidate in !messages.contains { $0.id == candidate.id } }
                hasOlder = page.count >= pageSize
                guard !unknown.isEmpty else { return }
                olderMessages.append(contentsOf: unknown)
                await apply(observed: messages)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Called by rows as they appear. Marking read is debounced so a fast scroll sends one receipt.
    func markVisible(_ id: MessageID) {
        guard let message = messages.first(where: { $0.id == id }), message.direction == .incoming, message.status != .read else { return }
        guard markReadTask == nil else { return }
        markReadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            defer { markReadTask = nil }
            do {
                let ids = try await deps.markRead.execute(conversationId: conversationId)
                if !ids.isEmpty { haptics.play(.read) }
            } catch {
                ChatLog.chat.error("mark read failed conversation=\(self.conversationId.description, privacy: .public)")
            }
        }
    }

    // MARK: Message actions

    /// Toggles a reaction: the protocol keeps one entry per emoji in a 1:1 chat, so reacting with an
    /// emoji that is already on the bubble removes it.
    func react(_ emoji: String, to id: MessageID) {
        guard let target = messages.first(where: { $0.id == id }) else { return }
        let remove = target.reactions.contains { $0.emoji == emoji }
        let payload = MessagePayload.reaction(Reaction(targetId: id, emoji: emoji, remove: remove))
        haptics.play(.sent)
        Task {
            do {
                _ = try await deps.sender.execute(conversationId: conversationId, payload: payload, expiresAt: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func retry(_ id: MessageID) {
        Task {
            do {
                _ = try await deps.sender.retry(messageId: id)
                haptics.play(.sent)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func reply(to message: Message) {
        replyingTo = message
        haptics.play(.lock)
    }

    /// Local delete only: the relay never learns about it, and the other side keeps its copy.
    func deleteLocally(_ id: MessageID) {
        Task {
            do {
                try await deps.messages.delete(ids: [id])
                olderMessages.removeAll { $0.id == id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func markRevealed(_ id: MessageID) {
        revealedMessageIds.insert(id)
    }

    func capsuleUnlocked(_ id: MessageID) {
        unlockedCapsuleIds.insert(id)
        haptics.play(.capsuleUnlock)
    }

    /// Whether a bubble should render as a sealed capsule right now.
    func isSealed(_ message: Message) -> Bool {
        guard let unlockAt = message.flags.unlockAt, message.direction == .incoming else { return false }
        return unlockAt > now && !unlockedCapsuleIds.contains(message.id)
    }

    /// Flips one bubble to the envelope the relay stored. The envelope is fetched lazily because the
    /// bytes are only interesting once someone asks to see them.
    func toggleServerView(for id: MessageID) {
        if flippedMessageIds.contains(id) {
            flippedMessageIds.remove(id)
            return
        }
        Task {
            await loadEnvelope(for: id)
            if rawEnvelopes[id] != nil {
                flippedMessageIds.insert(id)
            }
        }
    }

    func loadEnvelope(for id: MessageID) async {
        guard rawEnvelopes[id] == nil else { return }
        do {
            guard let envelope = try await deps.envelopes.envelope(for: id) else { throw ChatError.envelopeUnavailable }
            rawEnvelopes[id] = envelope
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Header actions

    func verify() {
        routes.onVerify(contact.id)
    }

    func toggleServersEye() {
        isServersEyePresented.toggle()
        ChatLog.serversEye.info("servers-eye \(self.isServersEyePresented ? "opened" : "closed", privacy: .public)")
    }

    /// Persists the timer on the conversation and announces the change as a system message so both
    /// sides see the same rule from the same moment.
    func setDisappearingTimer(_ timer: TimeInterval?) {
        guard conversation.disappearingTimer != timer else { return }
        conversation.disappearingTimer = timer
        let updated = conversation
        Task {
            do {
                try await deps.conversations.upsert(updated)
                let event = SystemEvent(kind: .disappearingChanged)
                _ = try await deps.sender.execute(conversationId: conversationId, payload: .system(event), expiresAt: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stage(_ attachment: StagedAttachment) {
        stagedAttachment = attachment
        if !attachment.isImage { composer.viewOnce = false }
    }

    func openAttachment(_ id: MessageID) {
        routes.onOpenAttachment(id)
    }
}
