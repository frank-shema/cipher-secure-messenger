import SwiftUI

/// Glassy capsule rendering a single `Toast`.
public struct ToastView: View {
    private let toast: Toast

    /// Creates a view for `toast`.
    public init(toast: Toast) {
        self.toast = toast
    }

    public var body: some View {
        HStack(spacing: CipherSpacing.sm) {
            Image(systemName: toast.systemImage ?? defaultIcon)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .semibold))
            Text(toast.message)
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, CipherSpacing.lg)
        .padding(.vertical, CipherSpacing.md)
        .background {
            Capsule()
                .fill(CipherColor.surfaceElevated.opacity(0.9))
                .overlay(Capsule().fill(CipherGradient.glassSheen))
                .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
        }
        .cipherShadow(.medium)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var defaultIcon: String {
        switch toast.style {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch toast.style {
        case .info: CipherColor.accent
        case .success: CipherColor.success
        case .warning: CipherColor.warning
        case .error: CipherColor.danger
        }
    }
}

#Preview {
    VStack(spacing: CipherSpacing.md) {
        ToastView(toast: Toast("Safety number verified", style: .success))
        ToastView(toast: Toast("Copied to clipboard"))
        ToastView(toast: Toast("Key changed for Ada", style: .warning))
        ToastView(toast: Toast("Message failed to send", style: .error))
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
