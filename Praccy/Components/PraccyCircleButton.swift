import SwiftUI

/// Circular accent button used in place of system toolbar/nav affordances.
struct PraccyCircleButton: View {
    let icon: PraccyIcon
    let palette: AccentPalette
    var size: CGFloat = 40
    var iconSize: CGFloat = 16
    var accessibilityLabel: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(palette.accent.opacity(isEnabled ? 1 : 0.4))
                PraccyIcon.view(for: icon, tint: palette.onAccent, size: iconSize)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.praccyPress(shadow: isEnabled ? palette.shadow : .clear))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Pill-shaped accent button for inline actions where a text label reads better than an icon.
struct PraccyPillButton: View {
    let title: String
    let palette: AccentPalette
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(palette.accent.opacity(isEnabled ? 1 : 0.4))
                )
        }
        .buttonStyle(.praccyPress(shadow: isEnabled ? palette.shadow : .clear, offset: 3))
        .disabled(!isEnabled)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        PraccyCircleButton(icon: .xmark, palette: .violet, accessibilityLabel: "Dismiss") { }
        PraccyCircleButton(icon: .check, palette: .violet, accessibilityLabel: "Confirm") { }
        PraccyPillButton(title: "Done", palette: .violet) { }
        PraccyPillButton(title: "Disabled", palette: .violet, isEnabled: false) { }
    }
    .padding(40)
    .background(AccentPalette.violet.bg)
}
#endif
