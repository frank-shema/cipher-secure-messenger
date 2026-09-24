import Foundation

enum ReactionApplier {
    /// Mirrors a reaction onto its target so the UI can read `Message.reactions` directly instead of
    /// scanning history. One entry per emoji is kept in a 1:1 chat.
    static func apply(_ reaction: Reaction, using messages: any MessageRepository) async throws {
        guard var target = try await messages.fetch(id: reaction.targetId) else { return }
        if reaction.remove {
            target.reactions.removeAll { $0.emoji == reaction.emoji }
        } else if !target.reactions.contains(where: { $0.emoji == reaction.emoji }) {
            target.reactions.append(Reaction(targetId: reaction.targetId, emoji: reaction.emoji))
        }
        try await messages.upsert(target)
    }
}
