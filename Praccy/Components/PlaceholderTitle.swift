import SwiftUI

/// Shared eyebrow + title block for stub screens so they stay cosmetically consistent.
struct PlaceholderTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(eyebrow)
                .praccyEyebrow()
                .foregroundStyle(PraccyColor.ink45)
            Text(title)
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
