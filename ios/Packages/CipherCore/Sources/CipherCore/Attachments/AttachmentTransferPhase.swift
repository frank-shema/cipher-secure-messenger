import Foundation

/// Where an attachment send is, reported per message id so a bubble can show one ring from the
/// moment it appears until the relay acknowledges the envelope.
public enum AttachmentUploadPhase: Hashable, Sendable {
    case sealing
    case uploading(fraction: Double)
    /// Blob stored; the message envelope is being sealed and sent.
    case sending
    case completed
    case failed

    /// A single 0…1 value for progress rings. Sealing and sending get small fixed slices so the ring
    /// moves before the first byte leaves and does not sit at 100% while the envelope is in flight.
    public var fraction: Double {
        switch self {
        case .sealing: 0.03
        case .uploading(let fraction): 0.05 + 0.9 * min(max(fraction, 0), 1)
        case .sending: 0.97
        case .completed, .failed: 1
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed: true
        case .sealing, .uploading, .sending: false
        }
    }
}

/// Download side of the same idea: verify and decrypt are short but not instant on a 25 MB file.
public enum AttachmentDownloadPhase: Hashable, Sendable {
    case downloading(fraction: Double)
    case verifying
    case decrypting
    case completed
    case failed

    public var fraction: Double {
        switch self {
        case .downloading(let fraction): 0.9 * min(max(fraction, 0), 1)
        case .verifying: 0.93
        case .decrypting: 0.97
        case .completed, .failed: 1
        }
    }
}
