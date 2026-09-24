import CipherCore
import Foundation

public enum QRPayloadError: Error, LocalizedError, Hashable, Sendable {
    /// Not a `cipher:verify` URI, or the scheme/path is wrong.
    case notACipherCode
    /// A newer protocol version this build cannot interpret.
    case unsupportedVersion(Int)
    /// A required field is absent or not decodable.
    case missingField(String)
    /// A key decoded to the wrong number of bytes.
    case keyLength(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .notACipherCode:
            CryptoStrings.localized("error.qr.notACipherCode", default: "This is not a Cipher verification code.")
        case .unsupportedVersion:
            CryptoStrings.localized("error.qr.unsupportedVersion", default: "This code was made by a newer version of Cipher.")
        case .missingField:
            CryptoStrings.localized("error.qr.missingField", default: "The verification code is incomplete.")
        case .keyLength:
            CryptoStrings.localized("error.qr.keyLength", default: "The verification code contains an invalid key.")
        }
    }
}

/// The contents of a verification QR code (PROTOCOL.md §4):
/// `cipher:verify?v=1&uid=<userId>&ik=<base64url>&sk=<base64url>`.
///
/// Scanning a contact's code and comparing it to the keys pinned from the directory proves the relay
/// did not substitute keys. Base64url without padding keeps the URI free of `+`, `/` and `=`, which
/// QR alphanumeric mode and URL parsers both mishandle.
public struct QRPayload: Hashable, Sendable {
    public static let scheme = "cipher"
    public static let action = "verify"
    public static let version = CipherCore.protocolVersion

    public var userId: UserID
    public var identityKey: Data
    public var signingKey: Data

    public init(userId: UserID, identityKey: Data, signingKey: Data) {
        self.userId = userId
        self.identityKey = identityKey
        self.signingKey = signingKey
    }

    public init(userId: UserID, keys: PublicKeyBundleUpload) {
        self.init(userId: userId, identityKey: keys.identityKey, signingKey: keys.signingKey)
    }

    public init(bundle: PublicKeyBundle) {
        self.init(userId: bundle.userId, identityKey: bundle.identityKey, signingKey: bundle.signingKey)
    }

    /// The string to encode into the QR image.
    public var encoded: String {
        let parameters = [
            "v=\(Self.version)",
            "uid=\(userId)",
            "ik=\(Base64URL.encode(identityKey))",
            "sk=\(Base64URL.encode(signingKey))"
        ]
        return "\(Self.scheme):\(Self.action)?" + parameters.joined(separator: "&")
    }

    public static func encode(userId: UserID, keys: PublicKeyBundleUpload) -> String {
        QRPayload(userId: userId, keys: keys).encoded
    }

    /// Parses a scanned string. Tolerates surrounding whitespace, uppercase scheme (QR alphanumeric
    /// mode upper-cases everything) and padded base64url, but nothing else.
    public static func decode(_ string: String) throws(QRPayloadError) -> QRPayload {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "\(scheme):\(action)?"
        guard trimmed.lowercased().hasPrefix(prefix) else { throw .notACipherCode }

        let query = trimmed.dropFirst(prefix.count)
        var fields: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            fields[parts[0].lowercased()] = String(parts[1])
        }

        guard let rawVersion = fields["v"], let parsedVersion = Int(rawVersion) else { throw .missingField("v") }
        guard parsedVersion == version else { throw .unsupportedVersion(parsedVersion) }
        guard let rawUser = fields["uid"], let userId = UserID(uuidString: rawUser) else { throw .missingField("uid") }
        guard let rawIdentity = fields["ik"], let identityKey = Base64URL.decode(rawIdentity) else { throw .missingField("ik") }
        guard let rawSigning = fields["sk"], let signingKey = Base64URL.decode(rawSigning) else { throw .missingField("sk") }
        try validateLength(identityKey)
        try validateLength(signingKey)
        return QRPayload(userId: userId, identityKey: identityKey, signingKey: signingKey)
    }

    /// True when the scanned keys match the bundle pinned from the directory.
    public func matches(_ bundle: PublicKeyBundle) -> Bool {
        bundle.userId == userId && bundle.identityKey == identityKey && bundle.signingKey == signingKey
    }

    private static func validateLength(_ key: Data) throws(QRPayloadError) {
        guard key.count == PublicKeyBundle.keyLength else {
            throw .keyLength(expected: PublicKeyBundle.keyLength, actual: key.count)
        }
    }
}

/// RFC 4648 §5 base64url, unpadded on output and padding-tolerant on input.
enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) -> Data? {
        var standard = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "=", with: "")
        let remainder = standard.count % 4
        if remainder > 0 {
            standard += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: standard)
    }
}
