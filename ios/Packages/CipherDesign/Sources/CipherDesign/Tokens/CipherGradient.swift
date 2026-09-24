import SwiftUI

/// Brand gradients. All are defined as `LinearGradient` values so they can be
/// used directly as `ShapeStyle` fills or backgrounds.
public enum CipherGradient {
    /// Outgoing bubble fill: electric teal flowing into signal blue.
    public static let outgoingBubble = LinearGradient(
        colors: [Color(hex: 0x2DD4BF), Color(hex: 0x2563EB)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hero gradient for onboarding and empty states: teal to violet over obsidian.
    public static let hero = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x2DD4BF), location: 0),
            .init(color: Color(hex: 0x8B5CF6), location: 0.55),
            .init(color: Color(hex: 0x0B0F1A), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Primary button fill.
    public static let primaryAction = LinearGradient(
        colors: [Color(hex: 0x2DD4BF), Color(hex: 0x14B8A6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Violet accent used for verified state and capsule reveals.
    public static let violet = LinearGradient(
        colors: [Color(hex: 0x8B5CF6), Color(hex: 0x6D28D9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle glass sheen laid over elevated surfaces.
    public static let glassSheen = LinearGradient(
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Skeleton shimmer band.
    public static let shimmer = LinearGradient(
        colors: [Color.white.opacity(0), Color.white.opacity(0.18), Color.white.opacity(0)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
