import SwiftUI

/// Top chrome row. Streak pill is student-only; teacher role drops it.
struct PraccyHeader: View {
    let role: UserRole
    let streak: Int
    let palette: AccentPalette
    var title: String? = nil
    var onBack: (() -> Void)? = nil
    var onStreakTap: (() -> Void)? = nil
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            if onBack == nil, let title, !title.isEmpty {
                Text(title)
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(PraccyColor.ink)
            }
            HStack(spacing: 12) {
                if let onBack {
                    Button(action: onBack) {
                        ZStack {
                            Circle().fill(palette.accent)
                            PraccyIcon.view(for: .chevronLeft, tint: palette.onAccent, size: 18)
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.praccyPress(shadow: palette.shadow))
                    .accessibilityLabel("Back")
                } else if role == .student {
                    StreakPill(days: streak, onTap: onStreakTap)
                }
                Spacer(minLength: 0)
                Button(action: onSettings) {
                    ZStack {
                        Circle().fill(palette.accent)
                        PraccyIcon.view(for: .settings, tint: palette.onAccent, size: 18)
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.praccyPress(shadow: palette.shadow))
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

#if DEBUG
#Preview("Header - student") {
    VStack {
        PraccyHeader(role: .student, streak: 14, palette: .violet, onSettings: {})
        Spacer()
    }
    .frame(height: 200)
    .background(AccentPalette.violet.bg)
}

#Preview("Header - teacher") {
    VStack {
        PraccyHeader(role: .teacher, streak: 0, palette: .violet, onSettings: {})
        Spacer()
    }
    .frame(height: 200)
    .background(AccentPalette.violet.bg)
}
#endif
