import Foundation

/// A minimal `multipart/form-data` encoder for the attachment upload (PROTOCOL.md §1.4). Only what the
/// relay reads is emitted: field parts and one binary part. The blob part is always sent as
/// `application/octet-stream` with a fixed filename so the relay never learns the real MIME type or name.
public struct MultipartFormData: Hashable, Sendable {
    public static let blobFilename = "blob"

    public let boundary: String
    private var parts: [Part] = []

    private struct Part: Hashable, Sendable {
        var headers: String
        var body: Data
    }

    public init(boundary: String = "cipher-" + UUID().uuidString.lowercased()) {
        self.boundary = boundary
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Adds a plain text field.
    public mutating func addField(name: String, value: String) {
        parts.append(Part(
            headers: "Content-Disposition: form-data; name=\"\(name)\"\r\n",
            body: Data(value.utf8)
        ))
    }

    /// Adds a binary part. Callers pass encrypted bytes only; the filename defaults to the neutral
    /// `blob` so nothing about the content leaks through the part headers.
    public mutating func addFile(
        name: String,
        data: Data,
        filename: String = MultipartFormData.blobFilename,
        contentType: String = "application/octet-stream"
    ) {
        parts.append(Part(
            headers: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
                + "Content-Type: \(contentType)\r\n",
            body: data
        ))
    }

    /// Serialises all parts with CRLF framing per RFC 7578.
    public func encoded() -> Data {
        var output = Data()
        for part in parts {
            output.append(Data("--\(boundary)\r\n".utf8))
            output.append(Data(part.headers.utf8))
            output.append(Data("\r\n".utf8))
            output.append(part.body)
            output.append(Data("\r\n".utf8))
        }
        output.append(Data("--\(boundary)--\r\n".utf8))
        return output
    }
}
