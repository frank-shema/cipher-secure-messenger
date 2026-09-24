import SwiftUI

/// The Cipher type scale. Every style is built with `Font.system(_:design:)`
/// on a semantic text style so Dynamic Type scaling is automatic.
///
/// SF Pro carries product copy; SF Mono is reserved for cipher glyphs,
/// fingerprints and anything that must read as "machine truth".
public enum CipherTypography {
    /// Large screen titles (onboarding, empty states).
    public static let title: Font = .system(.largeTitle, design: .rounded).weight(.bold)
    /// Section and card headlines.
    public static let headline: Font = .system(.headline, design: .rounded).weight(.semibold)
    /// Default reading size for message bodies and settings rows.
    public static let body: Font = .system(.body, design: .default)
    /// Timestamps, helper copy and metadata.
    public static let caption: Font = .system(.caption, design: .default).weight(.medium)
    /// Monospaced glyph rendering at body size.
    public static let mono: Font = .system(.body, design: .monospaced).weight(.medium)
    /// Monospaced hex captions and fingerprint fragments.
    public static let monoSmall: Font = .system(.caption2, design: .monospaced)

    /// Base point sizes at the default content size category, ordered by
    /// role. Exposed so tests and layout math can reason about the scale
    /// without resolving fonts.
    public enum BaseSize {
        public static let title: CGFloat = 34
        public static let headline: CGFloat = 17
        public static let body: CGFloat = 17
        public static let caption: CGFloat = 12
        public static let mono: CGFloat = 17
        public static let monoSmall: CGFloat = 11
    }
}
