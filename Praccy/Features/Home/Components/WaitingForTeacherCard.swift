import SwiftUI

/// Linked-but-nothing-assigned-today state. Read-only; students don't create tasks.
struct WaitingForTeacherCard: View {
    let palette: AccentPalette

    var body: some View {
        VStack(spacing: 8) {
            Text("Nothing assigned today")
                .font(PraccyFont.task)
                .tracking(-0.1)
            Text("Check back once your teacher sets your practice.")
                .font(PraccyFont.meta)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: PraccyRadius.card)
                .strokeBorder(
                    palette.accent.opacity(0.27),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
        )
        .accessibilityElement(children: .combine)
    }
}
