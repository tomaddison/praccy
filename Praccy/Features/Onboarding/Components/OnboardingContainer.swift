import SwiftUI

/// Onboarding progress dots. Hosted in chrome (not the step subtree) so the active capsule animates in place.
struct OnboardingProgressDots: View {
    let current: Int
    let total: Int
    let palette: AccentPalette

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? palette.accent : palette.accent.opacity(0.18))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        OnboardingProgressDots(current: 0, total: 7, palette: .violet)
        OnboardingProgressDots(current: 3, total: 7, palette: .violet)
        OnboardingProgressDots(current: 6, total: 7, palette: .violet)
    }
    .padding()
    .background(AccentPalette.violet.bg)
}
#endif
