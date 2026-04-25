import SwiftUI

/// Instrument name + icon. Reuses `InstrumentSection`; both fields optional.
struct InstrumentStep: View {
    let palette: AccentPalette
    let name: String
    let selectedIcon: String?
    let onNameChange: (String) -> Void
    let onIconChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What's your instrument?")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Pick a glyph that suits you. This shows next to your name.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .fixedSize(horizontal: false, vertical: true)

            InstrumentSection(
                name: name,
                selectedIcon: selectedIcon,
                palette: palette,
                onNameChange: onNameChange,
                onIconChange: onIconChange
            )
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Empty") {
    InstrumentStep(
        palette: .violet,
        name: "",
        selectedIcon: nil,
        onNameChange: { _ in },
        onIconChange: { _ in }
    )
}

#Preview("Filled") {
    InstrumentStep(
        palette: .violet,
        name: "Piano",
        selectedIcon: "pianokeys",
        onNameChange: { _ in },
        onIconChange: { _ in }
    )
}
#endif
