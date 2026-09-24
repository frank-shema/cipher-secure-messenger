import SwiftUI

/// Trust state for a contact's identity key.
public enum ShieldState: Sendable, Hashable {
    case unverified, verified, warning
}

/// A shield glyph communicating key verification status.
public struct ShieldBadge: View {
    private let state: ShieldState
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a badge for `state`.
    public init(state: ShieldState, size: CGFloat = 18) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .cipherShadow(state == .verified ? .glow : CipherShadow(color: .clear, radius: 0, y: 0))
            .contentTransition(.symbolEffect(.replace))
            .animation(reduceMotion ? nil : .snappy, value: state)
            .accessibilityLabel(Text(label))
    }

    private var symbol: String {
        switch state {
        case .unverified: "shield"
        case .verified: "checkmark.shield.fill"
        case .warning: "exclamationmark.shield.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .unverified: CipherColor.textSecondary
        case .verified: CipherColor.accent
        case .warning: CipherColor.warning
        }
    }

    private var label: String {
        switch state {
        case .unverified: "Keys not verified"
        case .verified: "Keys verified"
        case .warning: "Key changed, verify again"
        }
    }
}

#Preview {
    HStack(spacing: CipherSpacing.xl) {
        ShieldBadge(state: .unverified)
        ShieldBadge(state: .verified)
        ShieldBadge(state: .warning)
    }
    .padding()
    .background(CipherColor.background)
}
