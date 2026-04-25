import SwiftUI

/// Mascot-led empty state. Role-agnostic copy for roster / tasks / goals surfaces.
struct StudentEmptyState: View {
    let mood: PraccyMascotMood
    let headline: String
    let subtitle: String
    let ctaTitle: String?
    let palette: AccentPalette
    let onCTA: (() -> Void)?

    init(
        mood: PraccyMascotMood = .sleepy,
        headline: String,
        subtitle: String,
        ctaTitle: String? = nil,
        palette: AccentPalette,
        onCTA: (() -> Void)? = nil
    ) {
        self.mood = mood
        self.headline = headline
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.palette = palette
        self.onCTA = onCTA
    }

    var body: some View {
        VStack(spacing: 20) {
            PraccyMascot(size: 120, mood: mood, accent: palette.accent)
            VStack(spacing: 8) {
                Text(headline)
                    .font(PraccyFont.title)
                    .tracking(-0.6)
                    .foregroundStyle(PraccyColor.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.center)
            }
            if let ctaTitle, let onCTA {
                Button(action: onCTA) {
                    Text(ctaTitle)
                        .font(PraccyFont.task)
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge))
                }
                .buttonStyle(.praccyPress(shadow: palette.shadow))
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Empty roster") {
    StudentEmptyState(
        headline: "No students yet",
        subtitle: "Invite one with a join code.",
        ctaTitle: "Add your first student",
        palette: .violet,
        onCTA: {}
    )
    .background(AccentPalette.violet.bg)
}
#endif
