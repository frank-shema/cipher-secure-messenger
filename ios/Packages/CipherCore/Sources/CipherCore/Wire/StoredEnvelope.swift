import Foundation

/// An envelope as the relay stored it: the `Envelope` fields flattened together with the relay's
/// status and clocks. This is the item shape of `MessagePage` and the payload of `message.new`.
public struct StoredEnvelope: Hashable, Sendable {
    public var envelope: Envelope
    public var status: DeliveryStatus
    public var createdAt: Int64
    public var deliveredAt: Int64?
    public var readAt: Int64?

    public init(envelope: Envelope, status: DeliveryStatus, createdAt: Int64, deliveredAt: Int64? = nil, readAt: Int64? = nil) {
        self.envelope = envelope
        self.status = status
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.readAt = readAt
    }

    public var id: MessageID {
        envelope.id
    }

    public var serverCreatedAt: Date {
        Date(epochMillis: createdAt)
    }

    /// The relay clock that best explains the current status, for status-only reconciliation.
    public var statusChangedAt: Date {
        switch status {
        case .read: Date(epochMillis: readAt ?? deliveredAt ?? createdAt)
        case .delivered: Date(epochMillis: deliveredAt ?? createdAt)
        case .sent: serverCreatedAt
        }
    }
}

extension StoredEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case createdAt
        case deliveredAt
        case readAt
    }

    public init(from decoder: any Decoder) throws {
        envelope = try Envelope(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(DeliveryStatus.self, forKey: .status)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        deliveredAt = try container.decodeIfPresent(Int64.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(Int64.self, forKey: .readAt)
    }

    public func encode(to encoder: any Encoder) throws {
        try envelope.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(deliveredAt, forKey: .deliveredAt)
        try container.encode(readAt, forKey: .readAt)
    }
}
