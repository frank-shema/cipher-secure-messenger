import CipherCore
import Foundation

/// JSON coding for the blobs a row carries (payload, reactions, envelopes). Uses the protocol's
/// coders so a stored envelope is byte-identical to what went over the wire, which is the whole
/// point of keeping it for the Server's-Eye view.
enum StoredCodec {
    static func encode<T: Encodable>(_ value: T) throws(PersistenceError) -> Data {
        do {
            return try WireJSON.encode(value)
        } catch {
            throw .encodingFailed(PersistenceError.typeName(of: error))
        }
    }

    /// A blob that no longer decodes (schema drift, disk corruption) is reported as absent rather than
    /// failing the whole fetch, so one bad row cannot blank an entire conversation.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            return try WireJSON.decode(type, from: data)
        } catch {
            PersistenceLog.store.error(
                "stored \(String(describing: type), privacy: .public) unreadable: \(PersistenceError.typeName(of: error), privacy: .public)"
            )
            return nil
        }
    }
}
