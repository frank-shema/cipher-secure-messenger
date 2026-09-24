import SwiftUI

/// Delivery state for an outgoing message.
public enum BubbleStatus: Sendable, Hashable {
    case sending, sent, delivered, read, failed
}

/// A compact glyph showing an outgoing message's delivery status.
public struct BubbleStatusGlyph: View {
    private let status: BubbleStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a status glyph.
    public init(status: BubbleStatus) {
        self.status = status
    }

    public var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            case .sent:
                Image(systemName: "checkmark")
            case .delivered:
                doubleCheck(color: CipherColor.bubbleOutgoingText.opacity(0.8))
            case .read:
                doubleCheck(color: CipherColor.accent)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(CipherColor.danger)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(CipherColor.bubbleOutgoingText.opacity(0.8))
        .contentTransition(.symbolEffect(.replace))
        .animation(reduceMotion ? nil : .snappy, value: status)
        .accessibilityLabel(Text(label))
    }

    private func doubleCheck(color: Color) -> some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
        .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .sending: "Sending"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .read: "Read"
        case .failed: "Failed to send"
        }
    }
}

#Preview {
    HStack(spacing: CipherSpacing.lg) {
        BubbleStatusGlyph(status: .sending)
        BubbleStatusGlyph(status: .sent)
        BubbleStatusGlyph(status: .delivered)
        BubbleStatusGlyph(status: .read)
        BubbleStatusGlyph(status: .failed)
    }
    .padding()
    .background(CipherColor.bubbleOutgoing)
}
