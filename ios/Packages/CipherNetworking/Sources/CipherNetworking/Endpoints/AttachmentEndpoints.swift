import CipherCore
import Foundation

// `/api/v1/attachments/*` (PROTOCOL.md §1.4).

/// `POST /attachments` (multipart). The binary part is always named `file`, carries the filename `blob`
/// and the type `application/octet-stream`: the relay must learn nothing about what is inside.
public struct UploadAttachmentEndpoint: Endpoint {
    public typealias Response = BlobDescriptorDTO

    /// The relay rejects larger blobs with 413; the gateway checks before uploading so a 25 MiB body
    /// is never sent just to be refused.
    public static let maxBlobBytes = 25 * 1_024 * 1_024

    public var form: MultipartFormData

    public init(blob: Data, conversationId: ConversationID, expiresAtMillis: Int64?) {
        var form = MultipartFormData()
        form.addField(name: "conversationId", value: conversationId.description)
        if let expiresAtMillis {
            form.addField(name: "expiresAt", value: String(expiresAtMillis))
        }
        form.addFile(name: "file", data: blob)
        self.form = form
    }

    public var path: String { "attachments" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .multipart(form) }
    public var transferMode: TransferMode { .upload }
}

/// `GET /attachments/{blobId}` → `application/octet-stream`.
public struct DownloadAttachmentEndpoint: Endpoint {
    public typealias Response = RawResponse

    public var blobId: BlobID

    public init(blobId: BlobID) {
        self.blobId = blobId
    }

    public var path: String { "attachments/\(blobId.description)" }
    public var method: HTTPMethod { .get }
    public var transferMode: TransferMode { .download }
}
