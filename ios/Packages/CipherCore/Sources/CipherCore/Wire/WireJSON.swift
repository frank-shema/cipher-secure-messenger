import Foundation

/// JSON coders configured for the protocol: sorted keys for deterministic bytes, no escaped slashes
/// so `cipher/v1` style strings stay readable. Dates never appear on the wire (epoch millis do), so no
/// date strategy is needed and none should be added.
public enum WireJSON {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try makeEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }
}
