import SwiftUI

/// Sheet top row drawn by hand. iOS 26 toolbars wrap buttons in a system container that clashes with `PraccyCircleButton`.
struct PraccySheetHeader: View {
    let title: String
    let palette: AccentPalette
    let onDismiss: () -> Void

    private static let buttonDiameter: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)

            Text(title)
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            PraccyCircleButton(
                icon: .xmark,
                palette: palette,
                accessibilityLabel: "Close"
            ) { onDismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }
}

#if DEBUG
#Preview {
    VStack {
        PraccySheetHeader(title: "Settings", palette: .violet) { }
        Spacer()
    }
    .background(AccentPalette.violet.bg.ignoresSafeArea())
}
#endif
