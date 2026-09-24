import Foundation

/// Binary wire fields are standard base64 with padding (PROTOCOL.md conventions). These helpers keep
/// that rule in one place and make a malformed field a `DecodingError` rather than an empty `Data`.
extension KeyedDecodingContainer {
    func decodeBase64(forKey key: Key) throws -> Data {
        let raw = try decode(String.self, forKey: key)
        guard let data = Data(base64Encoded: raw) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not base64")
        }
        return data
    }

    func decodeBase64IfPresent(forKey key: Key) throws -> Data? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let data = Data(base64Encoded: raw) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not base64")
        }
        return data
    }
}

extension KeyedEncodingContainer {
    mutating func encodeBase64(_ data: Data, forKey key: Key) throws {
        try encode(data.base64EncodedString(), forKey: key)
    }

    mutating func encodeBase64(_ data: Data?, forKey key: Key) throws {
        try encode(data?.base64EncodedString(), forKey: key)
    }
}
