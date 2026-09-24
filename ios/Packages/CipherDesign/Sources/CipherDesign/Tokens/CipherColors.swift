import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum CipherColor {
    public static let background = dynamic(light: 0xF8FAFC, dark: 0x0B0F1A)
    public static let surface = dynamic(light: 0xFFFFFF, dark: 0x151B2B)
    public static let surfaceElevated = dynamic(light: 0xF1F5F9, dark: 0x1D2538)
    public static let accent = dynamic(light: 0x0D9488, dark: 0x2DD4BF)
    public static let accentSecondary = dynamic(light: 0x7C3AED, dark: 0x8B5CF6)
    public static let textPrimary = dynamic(light: 0x0F172A, dark: 0xF1F5F9)
    public static let textSecondary = dynamic(light: 0x475569, dark: 0x94A3B8)
    public static let success = dynamic(light: 0x059669, dark: 0x34D399)
    public static let warning = dynamic(light: 0xB45309, dark: 0xFBBF24)
    public static let danger = dynamic(light: 0xDC2626, dark: 0xF87171)
    public static let bubbleOutgoing = dynamic(light: 0x2563EB, dark: 0x2563EB)
    public static let bubbleIncoming = dynamic(light: 0xE2E8F0, dark: 0x1F2937)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(light: Color(hex: light), dark: Color(hex: dark))
    }
}

public extension Color {
    /// Dark is the brand's primary appearance, so it is the fallback wherever
    /// the platform cannot resolve a trait-driven color.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = dark
        #endif
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
