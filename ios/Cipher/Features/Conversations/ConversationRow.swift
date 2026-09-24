import CipherCore
import CipherDesign
import SwiftUI

/// One inbox row. The trust ring around the avatar makes verification status visible before the
/// thread is opened; the preview never exposes attachment names or sealed content.
struct ConversationRow: View {
    let conversation: Conversation
    let now: Date

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 52

    private var contact: Contact { conversation.contact }
    private var preview: String { MessageFormatting.preview(for: conversation.lastMessage) }
    private var hasUnread: Bool { conversation.unreadCount > 0 }

    var body: some View {
        HStack(spacing: CipherSpacing.md) {
            TrustRing(score: contact.trust.ringScore, size: avatarSize) {
                InitialsAvatar(name: contact.user.displayName, seed: contact.user.id.description, size: avatarSize - 10) {
                    PresenceDot(online: contact.presence.online, size: 12)
                        .offset(x: 1, y: 1)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: CipherSpacing.xs) {
                    Text(contact.user.displayName)
                        .font(CipherTypography.headline)
                        .foregroundStyle(CipherColor.textPrimary)
                        .lineLimit(1)
                    if contact.trust.isVerified {
                        ShieldBadge(state: .verified, size: 14)
                    } else if contact.trust.needsAttention {
                        ShieldBadge(state: .warning, size: 14)
                    }
                    Spacer(minLength: CipherSpacing.sm)
                    Text(MessageFormatting.inboxTimestamp(conversation.updatedAt, now: now))
                        .font(CipherTypography.caption)
                        .foregroundStyle(hasUnread ? CipherColor.accent : CipherColor.textSecondary)
                }
                HStack(alignment: .top, spacing: CipherSpacing.sm) {
                    previewLabel
                    Spacer(minLength: CipherSpacing.sm)
                    if hasUnread {
                        UnreadBadge(count: conversation.unreadCount)
                    } else if conversation.disappearingTimer != nil {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(CipherColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, CipherSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var previewLabel: some View {
        HStack(spacing: CipherSpacing.xs) {
            if let glyph = previewGlyph {
                Image(systemName: glyph)
                    .font(.caption)
                    .foregroundStyle(isTampered ? CipherColor.danger : CipherColor.textSecondary)
            }
            Text(preview)
                .font(.subheadline.weight(hasUnread ? .semibold : .regular))
                .foregroundStyle(isTampered ? CipherColor.danger : (hasUnread ? CipherColor.textPrimary : CipherColor.textSecondary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    private var isTampered: Bool { conversation.lastMessage?.content.isTampered == true }

    private var previewGlyph: String? {
        guard let message = conversation.lastMessage else { return nil }
        if message.flags.unlockAt.map({ $0 > now }) == true { return "envelope.badge.clock" }
        if message.flags.whisper { return "ear" }
        switch message.content {
        case .attachment(let attachment, _): return attachment.mimeType.hasPrefix("image/") ? "photo" : "doc"
        case .tampered: return "exclamationmark.shield"
        case .system: return "info.circle"
        case .text, .reaction: return message.direction == .outgoing ? "arrow.turn.up.right" : nil
        }
    }

    private var accessibilityText: String {
        var parts = [contact.user.displayName]
        if contact.trust.isVerified {
            parts.append(String(localized: "conversations.row.a11y.verified", defaultValue: "verified"))
        }
        if hasUnread {
            parts.append(String(localized: "conversations.row.a11y.unread",
                                defaultValue: "\(conversation.unreadCount) unread"))
        }
        parts.append(preview)
        parts.append(MessageFormatting.inboxTimestamp(conversation.updatedAt, now: now))
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List(PreviewMessaging.bundle().conversations) { conversation in
        ConversationRow(conversation: conversation, now: PreviewMessaging.frozenNow)
    }
    .listStyle(.plain)
}
