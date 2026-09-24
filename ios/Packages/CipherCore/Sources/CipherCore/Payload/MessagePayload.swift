import Foundation

/// Discriminator for what an encrypted payload carries (PROTOCOL.md §3).
public enum PayloadType: String, Hashable, Codable, Sendable, CaseIterable {
    case text
    case attachment
    case reaction
    case reply
    case system
}

/// The versioned JSON document that lives INSIDE the ciphertext. Everything about content — text,
/// attachment keys, reactions, disappearing flags — is here, so the relay never learns any of it.
public struct MessagePayload: Hashable, Sendable {
    public var version: Int
    public var type: PayloadType
    /// Text body, or the caption of an attachment.
    public var body: String?
    public var replyToId: MessageID?
    public var flags: MessageFlags
    public var attachment: Attachment?
    public var reaction: Reaction?
    public var system: SystemEvent?

    public init(
        version: Int = CipherCore.protocolVersion,
        type: PayloadType,
        body: String? = nil,
        replyToId: MessageID? = nil,
        flags: MessageFlags = .none,
        attachment: Attachment? = nil,
        reaction: Reaction? = nil,
        system: SystemEvent? = nil
    ) {
        self.version = version
        self.type = type
        self.body = body
        self.replyToId = replyToId
        self.flags = flags
        self.attachment = attachment
        self.reaction = reaction
        self.system = system
    }

    /// A text message; becomes a `reply` when quoting another message, as the protocol distinguishes them.
    public static func text(_ body: String, flags: MessageFlags = .none, replyTo: MessageID? = nil) -> MessagePayload {
        MessagePayload(type: replyTo == nil ? .text : .reply, body: body, replyToId: replyTo, flags: flags)
    }

    public static func attachment(
        _ attachment: Attachment,
        caption: String? = nil,
        flags: MessageFlags = .none,
        replyTo: MessageID? = nil
    ) -> MessagePayload {
        MessagePayload(type: .attachment, body: caption, replyToId: replyTo, flags: flags, attachment: attachment)
    }

    public static func reaction(_ reaction: Reaction) -> MessagePayload {
        MessagePayload(type: .reaction, reaction: reaction)
    }

    public static func system(_ event: SystemEvent) -> MessagePayload {
        MessagePayload(type: .system, system: event)
    }

    /// Rebuilds the payload a stored message was made from, for re-sealing on retry. Tampered content
    /// has no payload, so it cannot be re-sent.
    public init?(content: MessageContent, flags: MessageFlags, replyToId: MessageID?) {
        switch content {
        case .text(let body):
            self = .text(body, flags: flags, replyTo: replyToId)
        case .attachment(let attachment, let caption):
            self = .attachment(attachment, caption: caption, flags: flags, replyTo: replyToId)
        case .reaction(let reaction):
            self = .reaction(reaction)
        case .system(let event):
            self = .system(event)
        case .tampered:
            return nil
        }
    }

    /// The `type` field must agree with the populated fields; a payload that says `attachment` but
    /// carries none is malformed and is rejected before anything is persisted.
    public func validate() throws(MessagePayloadCodecError) {
        guard version == CipherCore.protocolVersion else {
            throw .unsupportedVersion(version)
        }
        let consistent: Bool = switch type {
        case .text, .reply: body != nil
        case .attachment: attachment != nil
        case .reaction: reaction != nil
        case .system: system != nil
        }
        guard consistent else { throw .inconsistent(type) }
    }

    /// Domain content for a validated payload. An inconsistent payload maps to `.tampered(.malformedPayload)`
    /// so the message still shows a warning instead of vanishing.
    public var content: MessageContent {
        switch type {
        case .text, .reply:
            return body.map { .text($0) } ?? .tampered(.malformedPayload)
        case .attachment:
            return attachment.map { .attachment($0, caption: body) } ?? .tampered(.malformedPayload)
        case .reaction:
            return reaction.map { .reaction($0) } ?? .tampered(.malformedPayload)
        case .system:
            return system.map { .system($0) } ?? .tampered(.malformedPayload)
        }
    }
}

extension MessagePayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case type
        case body
        case replyToId
        case flags
        case attachment
        case reaction
        case system
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        type = try container.decode(PayloadType.self, forKey: .type)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        replyToId = try container.decodeIfPresent(MessageID.self, forKey: .replyToId)
        flags = try container.decodeIfPresent(MessageFlags.self, forKey: .flags) ?? .none
        attachment = try container.decodeIfPresent(Attachment.self, forKey: .attachment)
        reaction = try container.decodeIfPresent(Reaction.self, forKey: .reaction)
        system = try container.decodeIfPresent(SystemEvent.self, forKey: .system)
    }

    /// Explicit `null`s (as in the PROTOCOL.md example) keep the encoded key set fixed regardless of type.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(type, forKey: .type)
        try container.encode(body, forKey: .body)
        try container.encode(replyToId, forKey: .replyToId)
        try container.encode(flags, forKey: .flags)
        try container.encode(attachment, forKey: .attachment)
        try container.encode(reaction, forKey: .reaction)
        try container.encode(system, forKey: .system)
    }
}
