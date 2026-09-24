import SwiftUI

/// A glassy elevated container with an optional title, used to group settings
/// and detail rows.
public struct SectionCard<Content: View>: View {
    private let title: String?
    private let content: Content

    /// Creates a card.
    /// - Parameters:
    ///   - title: Optional uppercase section title.
    ///   - content: Rows to display.
    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.sm) {
            if let title {
                Text(title.uppercased())
                    .font(CipherTypography.caption)
                    .foregroundStyle(CipherColor.textSecondary)
                    .padding(.horizontal, CipherSpacing.sm)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(CipherSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CipherRadius.lg)
                    .fill(CipherColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: CipherRadius.lg).fill(CipherGradient.glassSheen))
                    .overlay(RoundedRectangle(cornerRadius: CipherRadius.lg).strokeBorder(CipherColor.divider, lineWidth: 1))
            }
            .cipherShadow(.low)
        }
    }
}

#Preview {
    SectionCard(title: "Encryption") {
        HStack {
            ShieldBadge(state: .verified)
            Text("Keys verified with Ada")
                .font(CipherTypography.body)
                .foregroundStyle(CipherColor.textPrimary)
        }
        Divider().overlay(CipherColor.divider).padding(.vertical, CipherSpacing.md)
        Text("Signal Protocol · X25519 · AES-256-GCM")
            .font(CipherTypography.monoSmall)
            .foregroundStyle(CipherColor.textSecondary)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
