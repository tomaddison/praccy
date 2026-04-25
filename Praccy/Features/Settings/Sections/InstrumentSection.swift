import SwiftUI

/// Free-text instrument name + curated SF Symbol picker. Writes go out via callbacks.
struct InstrumentSection: View {
    let name: String
    let selectedIcon: String?
    let palette: AccentPalette
    let onNameChange: (String) -> Void
    let onIconChange: (String) -> Void

    @FocusState private var fieldFocused: Bool
    @State private var draftName: String

    init(
        name: String,
        selectedIcon: String?,
        palette: AccentPalette,
        onNameChange: @escaping (String) -> Void,
        onIconChange: @escaping (String) -> Void
    ) {
        self.name = name
        self.selectedIcon = selectedIcon
        self.palette = palette
        self.onNameChange = onNameChange
        self.onIconChange = onIconChange
        self._draftName = State(initialValue: name)
    }

    /// First entry is the default. `music.note` is the safety net across SF Symbols builds.
    static let iconOptions: [String] = [
        "music.note",
        "pianokeys",
        "guitars.fill",
        "music.mic",
        "tuningfork",
        "music.quarternote.3",
        "speaker.wave.2.fill",
        "waveform"
    ]

    private var effectiveIcon: String {
        selectedIcon ?? InstrumentSection.iconOptions.first ?? "music.note"
    }

    var body: some View {
        SettingsSectionCard(eyebrow: "Instrument", palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("e.g. Piano", text: $draftName)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitName() }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused { commitName() }
                    }
                    .onChange(of: name) { _, newValue in
                        if !fieldFocused { draftName = newValue }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                            .fill(palette.surface.opacity(0.5))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                            .strokeBorder(palette.accent.opacity(0.18), lineWidth: 1.5)
                    }

                Text("Icon")
                    .praccyEyebrow()
                    .tracking(1)
                    .foregroundStyle(PraccyColor.ink60)
                    .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(InstrumentSection.iconOptions, id: \.self) { symbol in
                            iconChip(symbol)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func iconChip(_ symbol: String) -> some View {
        let isSelected = symbol == effectiveIcon
        Button {
            onIconChange(symbol)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? palette.accent : palette.surface)
                Image(systemName: symbol)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(isSelected ? palette.onAccent : palette.accent)
            }
            .frame(width: 48, height: 48)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(palette.accent, lineWidth: 2.5)
                        .padding(-4)
                }
            }
        }
        .buttonStyle(.praccyPress(offset: 2))
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func commitName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != name {
            onNameChange(trimmed)
        }
        draftName = trimmed
    }
}

#if DEBUG
#Preview("Default") {
    InstrumentSection(
        name: "",
        selectedIcon: nil,
        palette: .violet,
        onNameChange: { _ in },
        onIconChange: { _ in }
    )
    .padding(22)
    .background(AccentPalette.violet.bg)
}

#Preview("Filled") {
    InstrumentSection(
        name: "Harp",
        selectedIcon: "tuningfork",
        palette: .violet,
        onNameChange: { _ in },
        onIconChange: { _ in }
    )
    .padding(22)
    .background(AccentPalette.violet.bg)
}
#endif
