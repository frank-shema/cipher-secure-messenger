import Foundation

public enum MessagePayloadCodecError: Error, LocalizedError, Hashable, Sendable {
    case encodingFailed(String)
    case malformed(String)
    case unsupportedVersion(Int)
    case inconsistent(PayloadType)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            CoreStrings.localized("error.payload.encodingFailed", default: "The message could not be prepared.")
        case .malformed:
            CoreStrings.localized("error.payload.malformed", default: "The message content is malformed.")
        case .unsupportedVersion:
            CoreStrings.localized("error.payload.unsupportedVersion", default: "This message uses a newer version of Cipher.")
        case .inconsistent:
            CoreStrings.localized("error.payload.inconsistent", default: "The message content is inconsistent.")
        }
    }
}

/// Encodes and decodes the plaintext that goes into the AEAD. Keys are sorted so the same payload
/// always produces the same bytes, which keeps tests deterministic and makes ciphertext size
/// independent of dictionary ordering.
public struct MessagePayloadCodec: Sendable {
    public init() {}

    public func encode(_ payload: MessagePayload) throws(MessagePayloadCodecError) -> Data {
        try payload.validate()
        do {
            return try WireJSON.encode(payload)
        } catch {
            throw .encodingFailed(String(describing: type(of: error)))
        }
    }

    public func decode(_ data: Data) throws(MessagePayloadCodecError) -> MessagePayload {
        let payload: MessagePayload
        do {
            payload = try WireJSON.decode(MessagePayload.self, from: data)
        } catch {
            throw .malformed(String(describing: type(of: error)))
        }
        try payload.validate()
        return payload
    }
}
