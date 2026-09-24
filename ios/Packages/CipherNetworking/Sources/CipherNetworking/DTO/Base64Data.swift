import Foundation

/// A binary wire field. PROTOCOL.md mandates standard base64 with padding for every `Data` on the wire;
/// decoding through this wrapper turns a malformed field into a `DecodingError` (and so an
/// `APIError.decoding`) instead of an empty `Data` that would later fail as a bogus key or signature.
public struct Base64Data: Hashable, Codable, Sendable {
    public var data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let data = Data(base64Encoded: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not standard base64")
        }
        self.data = data
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }
}
