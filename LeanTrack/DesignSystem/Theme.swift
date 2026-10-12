import SwiftUI
import UIKit

/// Colors, sizes and fonts shared by every screen.
/// Dark values match the design reference; light values are used when the
/// Appearance setting is Light (or System while the phone is in light mode).
enum Theme {
    // MARK: Surfaces
    static let background = Color(light: 0xF2F2F7, dark: 0x000000)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let cardElevated = Color(light: 0xE5E5EA, dark: 0x2C2C2E)
    static let separator = Color(light: 0xC6C6C8, dark: 0x38383A)
    static let tabBarBackground = Color(light: 0xF9F9F9, dark: 0x0A0A0A)

    // MARK: Text
    static let textPrimary = Color(light: 0x000000, dark: 0xFFFFFF)
    static let textSecondary = Color(light: 0x6C6C70, dark: 0x8E8E93)

    // MARK: Accents
    static let accent = Color(light: 0x007AFF, dark: 0x0A84FF)
    static let calorieRing = Color(light: 0x28B84C, dark: 0x30D158)
    static let positive = Color(light: 0x248A3D, dark: 0x30D158)
    static let danger = Color(light: 0xD70015, dark: 0xFF453A)
    static let water = Color(light: 0x0071A4, dark: 0x64D2FF)
    static let streak = Color(light: 0xC93400, dark: 0xFF9F0A)

    // MARK: Macros (same colors everywhere: dots, rings, bars, legends)
    static let protein = Color(light: 0x28B84C, dark: 0x30D158)
    static let carbs = Color(light: 0x2F5BEA, dark: 0x4C74FF)
    static let fat = Color(light: 0xC96A00, dark: 0xFF9F0A)

    // MARK: Shape
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 12
    static let screenPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
}

extension Color {
    /// A color that switches between two hex values with the light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
