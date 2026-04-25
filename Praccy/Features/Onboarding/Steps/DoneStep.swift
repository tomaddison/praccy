import SwiftUI

/// Confirmation step with confetti on appear. CTA lives in `OnboardingFlow`'s footer.
struct DoneStep: View {
    let palette: AccentPalette
    let role: UserRole

    @State private var showBurst: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            ZStack {
                PraccyMascot(size: 160, mood: .excited, accent: palette.accent, swing: true)
                if showBurst {
                    ConfettiBurst(accent: palette.accent) {
                        showBurst = false
                    }
                    .frame(width: 240, height: 240)
                    .allowsHitTesting(false)
                }
            }

            VStack(spacing: 10) {
                Text("You're all set.")
                    .font(PraccyFont.title)
                    .tracking(-0.6)
                    .foregroundStyle(PraccyColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Delay so the step transition settles before the burst; otherwise it arrives mid-slide.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showBurst = true
            }
        }
    }
}

#if DEBUG
#Preview("Student") {
    DoneStep(palette: .violet, role: .student)
}

#Preview("Teacher") {
    DoneStep(palette: .violet, role: .teacher)
}
#endif
