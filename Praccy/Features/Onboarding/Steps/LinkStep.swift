import SwiftUI

/// Student-only link step. Teachers reach the equivalent surface via the Students tab empty state.
struct LinkStep: View {
    let palette: AccentPalette
    @Binding var code: String
    let errorMessage: String?
    let isSubmitting: Bool

    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Enter your teacher's code.")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Your teacher will share a six-character code. Paste or type it here to link up.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .fixedSize(horizontal: false, vertical: true)

            codeField
                .padding(.top, 6)

            if let errorMessage {
                Text(errorMessage)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .onAppear { codeFieldFocused = true }
    }

    private var codeField: some View {
        TextField("XXXXXX", text: $code)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
            .keyboardType(.asciiCapable)
            .font(PraccyFont.title)
            .tracking(8)
            .foregroundStyle(PraccyColor.ink)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PraccyRadius.card)
                    .strokeBorder(palette.accent.opacity(0.25), lineWidth: 1.5)
            }
            .praccySolidShadow(color: palette.shadow.opacity(0.25), offset: 3)
            .disabled(isSubmitting)
            .focused($codeFieldFocused)
            .onChange(of: code) { _, newValue in
                let filtered = newValue
                    .uppercased()
                    .filter { JoinCodeGenerator.alphabet.contains($0) }
                let clipped = String(filtered.prefix(JoinCodeGenerator.codeLength))
                if clipped != newValue { code = clipped }
            }
    }
}

#if DEBUG
#Preview("Empty") {
    LinkStep(
        palette: .violet,
        code: .constant(""),
        errorMessage: nil,
        isSubmitting: false
    )
    .padding(24)
    .background(AccentPalette.violet.bg)
}

#Preview("Error") {
    LinkStep(
        palette: .violet,
        code: .constant("XYZ123"),
        errorMessage: "That code doesn't match a teacher.",
        isSubmitting: false
    )
    .padding(24)
    .background(AccentPalette.violet.bg)
}
#endif
