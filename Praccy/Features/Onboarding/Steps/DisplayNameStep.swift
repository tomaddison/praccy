import SwiftUI

/// Display name entry. Writes on every keystroke so the parent CTA can gate on the trimmed value.
struct DisplayNameStep: View {
    let palette: AccentPalette
    let initialName: String
    let onNameChange: (String) -> Void
    let onSubmit: () -> Void

    @State private var draft: String
    @FocusState private var focused: Bool

    init(
        palette: AccentPalette,
        initialName: String,
        onNameChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.palette = palette
        self.initialName = initialName
        self.onNameChange = onNameChange
        self.onSubmit = onSubmit
        self._draft = State(initialValue: initialName)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What's your name?")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("We'll show this to your teacher when you link up.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)

            TextField("e.g. Luca", text: $draft)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(submitIfValid)
                .onChange(of: draft) { _, newValue in
                    onNameChange(newValue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                        .strokeBorder(palette.accent.opacity(0.2), lineWidth: 1.5)
                )
                .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .onAppear {
            // Tiny delay so the transition lands before the keyboard
            // animates in - otherwise the two animations collide.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = true
            }
        }
    }

    private func submitIfValid() {
        guard !trimmed.isEmpty else { return }
        focused = false
        onSubmit()
    }
}

#if DEBUG
#Preview("Empty") {
    DisplayNameStep(
        palette: .violet,
        initialName: "",
        onNameChange: { _ in },
        onSubmit: {}
    )
}

#Preview("Pre-filled") {
    DisplayNameStep(
        palette: .violet,
        initialName: "Luca",
        onNameChange: { _ in },
        onSubmit: {}
    )
}
#endif
