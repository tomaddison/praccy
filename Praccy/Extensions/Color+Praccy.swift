import SwiftUI

// MARK: - RGB

/// Kept raw because SwiftUI's `Color` erases channels at init, blocking `× 0.6` shadow math.
struct RGB: Equatable, Hashable {
    let r: Double
    let g: Double
    let b: Double

    init(_ hex: UInt32) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    func multiplied(by factor: Double) -> RGB {
        RGB(r: r * factor, g: g * factor, b: b * factor)
    }
}

// MARK: - Hex initialiser

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Fixed colour tokens

enum PraccyColor {
    static let ink = Color(hex: 0x1A1A2E)
    static let streakOrange = Color(hex: 0xFF9642)
    static let streakOrangeShadow = Color(hex: 0xB25410)
    static let streakEgg = Color(hex: 0xFFDA8A)
    static let streakFlame = Color(hex: 0xFF4A00)
    static let success = Color(hex: 0x16A34A)
    static let warning = Color(hex: 0xEF4444)
    static let cheek = Color(hex: 0xFFB8C4)

    static let ink60 = ink.opacity(0.60)
    static let ink45 = ink.opacity(0.45)
    static let ink40 = ink.opacity(0.40)
    static let ink10 = ink.opacity(0.10)
    static let ink08 = ink.opacity(0.08)
    static let ink05 = ink.opacity(0.05)
}
