import SwiftUI

/// Cold-open welcome step. CTA is in `OnboardingFlow`'s footer.
struct WelcomeStep: View {
    let palette: AccentPalette

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)
            PraccyMascot(size: 160, mood: .happy, accent: palette.accent, swing: true)
            VStack(spacing: 10) {
                Text("Welcome to Praccy.")
                    .font(PraccyFont.title)
                    .tracking(-0.6)
                    .foregroundStyle(PraccyColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Let's get you set up.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    WelcomeStep(palette: .violet)
}
#endif
