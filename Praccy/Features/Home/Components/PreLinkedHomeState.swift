import SwiftUI

/// Signed-in student with no active `TeacherLink`. Fires the parent callback on CTA tap.
struct PreLinkedHomeState: View {
    let palette: AccentPalette
    let onEnterCode: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            PraccyMascot(size: 120, mood: .happy, accent: palette.accent)
            VStack(spacing: 8) {
                Text("Welcome to Praccy")
                    .font(PraccyFont.title)
                    .tracking(-0.6)
                    .foregroundStyle(PraccyColor.ink)
                    .multilineTextAlignment(.center)
                Text("Enter the code your teacher gave you to get started.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.center)
            }
            Button(action: onEnterCode) {
                Text("Enter teacher code")
                    .font(PraccyFont.task)
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge))
            }
            .buttonStyle(.praccyPress(shadow: palette.shadow))
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
