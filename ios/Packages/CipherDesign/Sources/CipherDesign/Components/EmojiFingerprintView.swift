import SwiftUI

/// A 4x2 grid of large emoji representing a key fingerprint, with an
/// optional mono hex caption beneath for byte-level comparison.
public struct EmojiFingerprintView<Caption: View>: View {
    private let emoji: [String]
    private let caption: Caption

    /// Creates a fingerprint view.
    /// - Parameters:
    ///   - emoji: Exactly eight emoji; extras are ignored, gaps are shown as placeholders.
    ///   - caption: Slot for the hex fingerprint; use `Text(...).font(CipherTypography.monoSmall)`.
    public init(emoji: [String], @ViewBuilder caption: () -> Caption) {
        self.emoji = emoji
        self.caption = caption()
    }

    private var cells: [String] {
        Array((emoji + Array(repeating: "·", count: 8)).prefix(8))
    }

    public var body: some View {
        VStack(spacing: CipherSpacing.lg) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CipherSpacing.md), count: 4), spacing: CipherSpacing.md) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, glyph in
                    Text(glyph)
                        .font(.system(size: 36))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(CipherColor.surfaceElevated, in: .rect(cornerRadius: CipherRadius.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: CipherRadius.md)
                                .strokeBorder(CipherColor.divider, lineWidth: 1)
                        }
                }
            }
            caption
                .font(CipherTypography.monoSmall)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Fingerprint: \(cells.joined(separator: ", "))"))
    }
}

public extension EmojiFingerprintView where Caption == EmptyView {
    /// Creates a fingerprint view without a caption.
    init(emoji: [String]) {
        self.init(emoji: emoji) { EmptyView() }
    }
}

#Preview {
    EmojiFingerprintView(emoji: ["🦊", "🔑", "🌊", "🎯", "🪐", "🧩", "🍀", "⚡️"]) {
        Text("3F9A 2C11 8B0D E4F7  91AC 5D3E 0B77 C2A9")
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
