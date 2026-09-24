import SwiftUI

/// Transport connectivity as surfaced to the user.
public enum ConnectionState: Sendable, Hashable {
    case connecting
    case offline
    /// Reconnecting with a countdown in seconds.
    case reconnecting(in: Int)
    case connected
}

/// A slim banner that slides in from the top to report connection state and
/// slides away once connected.
public struct ConnectionBanner: View {
    private let state: ConnectionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a banner for `state`. Hidden when `.connected`.
    public init(state: ConnectionState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            if state != .connected {
                HStack(spacing: CipherSpacing.sm) {
                    Image(systemName: icon)
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && state != .offline)
                    Text(message)
                        .font(CipherTypography.caption)
                }
                .foregroundStyle(CipherColor.textPrimary)
                .padding(.horizontal, CipherSpacing.lg)
                .padding(.vertical, CipherSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(tint.opacity(0.18))
                .overlay(alignment: .bottom) { CipherColor.divider.frame(height: 1) }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.2), value: state)
    }

    private var icon: String {
        switch state {
        case .connecting: "antenna.radiowaves.left.and.right"
        case .offline: "wifi.slash"
        case .reconnecting: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle"
        }
    }

    private var tint: Color {
        switch state {
        case .connecting, .reconnecting: CipherColor.warning
        case .offline: CipherColor.danger
        case .connected: CipherColor.success
        }
    }

    private var message: String {
        switch state {
        case .connecting: "Connecting…"
        case .offline: "You're offline. Messages will send when you're back."
        case .reconnecting(let seconds): "Reconnecting in \(seconds)s…"
        case .connected: "Connected"
        }
    }
}

#Preview {
    VStack(spacing: CipherSpacing.md) {
        ConnectionBanner(state: .connecting)
        ConnectionBanner(state: .offline)
        ConnectionBanner(state: .reconnecting(in: 4))
        ConnectionBanner(state: .connected)
    }
    .background(CipherColor.background)
}
