import SwiftUI

/// Elevation shadows tuned for obsidian surfaces: soft, low-opacity and
/// slightly tinted toward the accent so glass panels feel lit from within.
public struct CipherShadow: Sendable {
    /// Shadow tint.
    public let color: Color
    /// Blur radius.
    public let radius: CGFloat
    /// Vertical offset.
    public let y: CGFloat

    /// Creates a custom shadow token.
    public init(color: Color, radius: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.y = y
    }

    /// Resting cards and list rows.
    public static let low = CipherShadow(color: .black.opacity(0.18), radius: 6, y: 2)
    /// Sheets, toasts and floating controls.
    public static let medium = CipherShadow(color: .black.opacity(0.28), radius: 14, y: 6)
    /// Modals and hero surfaces.
    public static let high = CipherShadow(color: .black.opacity(0.38), radius: 28, y: 12)
    /// Accent-tinted glow used behind primary actions and verified shields.
    public static let glow = CipherShadow(color: Color(hex: 0x2DD4BF).opacity(0.35), radius: 18, y: 0)
}

public extension View {
    /// Applies a `CipherShadow` token.
    func cipherShadow(_ shadow: CipherShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
