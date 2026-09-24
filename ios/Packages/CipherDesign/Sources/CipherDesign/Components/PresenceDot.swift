import SwiftUI

/// A small status dot indicating whether a contact is online.
public struct PresenceDot: View {
    private let online: Bool
    private let size: CGFloat

    /// Creates a presence dot.
    /// - Parameters:
    ///   - online: `true` renders success green; `false` renders muted grey.
    ///   - size: Diameter in points.
    public init(online: Bool, size: CGFloat = 12) {
        self.online = online
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(online ? CipherColor.success : CipherColor.textSecondary.opacity(0.6))
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(CipherColor.surface, lineWidth: size * 0.18))
            .accessibilityLabel(Text(online ? "Online" : "Offline"))
    }
}

#Preview {
    HStack(spacing: CipherSpacing.md) {
        PresenceDot(online: true)
        PresenceDot(online: false)
    }
    .padding()
    .background(CipherColor.background)
}
