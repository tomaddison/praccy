import SwiftUI

// MARK: - Accent palette

/// Single-theme palette. Kept as a value with a `.violet` constant so call sites
/// taking `palette: AccentPalette` still compose cleanly.
struct AccentPalette {
    static let violet = AccentPalette()

    var accent: Color { Color(hex: 0x8B5CF6) }
    var surface: Color { Color(hex: 0xEEE4FF) }
    var bg: Color { Color(hex: 0xF0E8FA) }
    var shadow: Color { RGB(0x8B5CF6).multiplied(by: 0.6).color }
    /// Shadow used under white-background cards (to-dos, goals, calendar).
    var softShadow: Color { shadow.opacity(0.35) }
    var onAccent: Color { .white }
}

// MARK: - Radius / hit-target tokens

enum PraccyRadius {
    static let card: CGFloat = 26
    static let pill: CGFloat = 20
    static let buttonLarge: CGFloat = 20
    static let buttonSmall: CGFloat = 18
    static let chip: CGFloat = 999
    static let tabBar: CGFloat = 28
    static let tab: CGFloat = 22

    /// Minimum tappable hit target (Apple HIG).
    static let minHitTarget: CGFloat = 44
}

// MARK: - Animation tokens

/// State changes snap; only physical motion (metronome beat, beat-dot reflow) is animated.
enum PraccyAnimation {
    static let bounce: Animation = .spring(response: 0.25, dampingFraction: 0.8)
    static let beatAttack: Animation = .easeOut(duration: 0.04)
    static let beatSettle: Animation = .spring(response: 0.2, dampingFraction: 0.55)
}
