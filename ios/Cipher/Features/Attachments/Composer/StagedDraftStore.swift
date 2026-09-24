import CipherCore
import Foundation

/// Holds the plaintext bytes of attachments staged in a composer until they are sent or replaced.
/// The chat ViewModel only sees the lightweight `StagedAttachment`; the bytes stay here, in memory,
/// keyed by its id. One draft per conversation: staging a new pick releases the previous bytes.
actor StagedDraftStore {
    private var drafts: [UUID: AttachmentDraft] = [:]
    private var byConversation: [ConversationID: UUID] = [:]

    func store(_ draft: AttachmentDraft, id: UUID, conversationId: ConversationID) {
        if let previous = byConversation[conversationId] {
            drafts.removeValue(forKey: previous)
        }
        drafts[id] = draft
        byConversation[conversationId] = id
    }

    /// Removes and returns the draft; a send consumes it exactly once.
    func take(_ id: UUID) -> AttachmentDraft? {
        guard let draft = drafts.removeValue(forKey: id) else { return nil }
        byConversation = byConversation.filter { $0.value != id }
        return draft
    }

    func discard(conversationId: ConversationID) {
        guard let id = byConversation.removeValue(forKey: conversationId) else { return }
        drafts.removeValue(forKey: id)
    }

    var count: Int { drafts.count }
}
