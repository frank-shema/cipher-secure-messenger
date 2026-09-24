import SwiftUI

public extension CipherColor {
    /// Color for cipher glyphs rendered in SF Mono; slightly desaturated teal
    /// so long glyph runs do not overpower message text.
    static let glyph = Color(light: Color(hex: 0x0F766E), dark: Color(hex: 0x5EEAD4))

    /// Hairline separators between rows and sections.
    static let divider = Color(light: Color(hex: 0x0F172A).opacity(0.08), dark: Color(hex: 0xF1F5F9).opacity(0.08))

    /// Scrim laid behind sheets, toasts and view-once placeholders.
    static let overlay = Color(light: Color(hex: 0x0F172A).opacity(0.45), dark: Color(hex: 0x000000).opacity(0.6))

    /// Text on top of the outgoing bubble gradient; always light.
    static let bubbleOutgoingText = Color(hex: 0xF8FAFC)
}
