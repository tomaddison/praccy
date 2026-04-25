import SwiftUI

struct MascotHero: View {
    let progress: Double
    let palette: AccentPalette

    private var mood: PraccyMascotMood {
        if progress >= 1 { return .excited }
        if progress >= 0.5 { return .happy }
        return .sleepy
    }

    private var headline: String {
        if progress >= 1 { return "All done." }
        if progress > 0 { return "Keep going." }
        return "Let's play."
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            PraccyMascot(size: 92, mood: mood, accent: palette.accent, dailyProgress: progress)
                .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(PraccyFont.title)
                    .tracking(-0.6)
                    .foregroundStyle(PraccyColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
