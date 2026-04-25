import SwiftUI

/// Rounded white card with the eyebrow label floating above on `palette.bg`.
struct SettingsSectionCard<Content: View>: View {
    let eyebrow: String
    let palette: AccentPalette
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .praccyEyebrow()
                .foregroundStyle(palette.accent)
                .padding(.leading, 4)

            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
                .praccySolidShadow(color: palette.shadow.opacity(0.25), offset: 3)
        }
    }
}

#if DEBUG
#Preview("Section card") {
    SettingsSectionCard(eyebrow: "Account", palette: .violet) {
        Text("Card body goes here.")
            .font(PraccyFont.task)
            .foregroundStyle(PraccyColor.ink)
    }
    .padding(22)
    .background(AccentPalette.violet.bg)
}
#endif
