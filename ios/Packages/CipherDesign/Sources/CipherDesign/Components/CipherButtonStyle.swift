import SwiftUI

/// The three Cipher button treatments.
public enum CipherButtonVariant: Sendable {
    /// Filled teal gradient with glow; one per screen.
    case primary
    /// Borderless accent text on a translucent surface.
    case ghost
    /// Filled danger red for irreversible actions.
    case destructive
}

/// Button style implementing the Cipher variants with press scaling that
/// respects Reduce Motion.
public struct CipherButtonStyle: ButtonStyle {
    private let variant: CipherButtonVariant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    /// Creates a style for `variant`.
    public init(_ variant: CipherButtonVariant) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CipherTypography.headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, CipherSpacing.xl)
            .padding(.vertical, CipherSpacing.md + 2)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(background(pressed: configuration.isPressed), in: .rect(cornerRadius: CipherRadius.md))
            .overlay {
                if variant == .ghost {
                    RoundedRectangle(cornerRadius: CipherRadius.md)
                        .strokeBorder(CipherColor.accent.opacity(0.35), lineWidth: 1)
                }
            }
            .cipherShadow(variant == .primary && isEnabled ? .glow : CipherShadow(color: .clear, radius: 0, y: 0))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: Color(hex: 0x0B0F1A)
        case .ghost: CipherColor.accent
        case .destructive: .white
        }
    }

    private func background(pressed: Bool) -> AnyShapeStyle {
        let dim = pressed ? 0.85 : 1
        switch variant {
        case .primary: return AnyShapeStyle(CipherGradient.primaryAction.opacity(dim))
        case .ghost: return AnyShapeStyle(CipherColor.accent.opacity(pressed ? 0.16 : 0.08))
        case .destructive: return AnyShapeStyle(CipherColor.danger.opacity(dim))
        }
    }
}

public extension ButtonStyle where Self == CipherButtonStyle {
    /// `CipherButtonStyle(.primary)`.
    static var cipherPrimary: CipherButtonStyle { CipherButtonStyle(.primary) }
    /// `CipherButtonStyle(.ghost)`.
    static var cipherGhost: CipherButtonStyle { CipherButtonStyle(.ghost) }
    /// `CipherButtonStyle(.destructive)`.
    static var cipherDestructive: CipherButtonStyle { CipherButtonStyle(.destructive) }
}

/// Convenience button with a title, optional SF Symbol and a Cipher variant.
public struct CipherButton: View {
    private let title: String
    private let systemImage: String?
    private let variant: CipherButtonVariant
    private let action: () -> Void

    /// Creates a button.
    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: CipherButtonVariant = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: CipherSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(CipherButtonStyle(variant))
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    VStack(spacing: CipherSpacing.lg) {
        CipherButton("Verify keys", systemImage: "checkmark.shield") {}
        CipherButton("Not now", variant: .ghost) {}
        CipherButton("Delete conversation", systemImage: "trash", variant: .destructive) {}
        CipherButton("Disabled", variant: .primary) {}.disabled(true)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
