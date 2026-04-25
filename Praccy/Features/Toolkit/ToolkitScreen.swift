import SwiftUI
import SwiftData

/// Two-card picker routing to the drone tuner or accent-pattern metronome. Owns both services
/// so switching mid-play stops audio cleanly.
struct ToolkitScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [UserSettings]

    let palette: AccentPalette

    @State private var mode: ToolkitMode = .tuner
    @State private var tuner = Tuner()
    @State private var metronome = Metronome()
    @State private var didHydrate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ModePicker(mode: $mode, palette: palette, onSwitch: handleModeSwitch)

                // Instant swap; no fade.
                Group {
                    switch mode {
                    case .tuner:
                        TunerView(tuner: tuner, palette: palette, settings: currentSettings)
                    case .metronome:
                        MetronomeView(metronome: metronome, palette: palette, settings: currentSettings)
                    }
                }
                .animation(nil, value: mode)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .task {
            hydrateFromSettings()
            tuner.prepare()
            metronome.prepare()
        }
    }

    private var currentSettings: UserSettings? {
        settingsRows.first
    }

    /// First-render hydrate from `UserSettings`. `@Query` keeps the row live so later writes flow back out via bindings.
    private func hydrateFromSettings() {
        guard !didHydrate, let settings = currentSettings else { return }
        didHydrate = true

        if let raw = settings.lastUsedTunerNote, let note = TunerNote(rawValue: raw) {
            tuner.note = note
        }
        if let octave = settings.lastUsedTunerOctave {
            tuner.octave = octave
        }
        if let ref = settings.lastUsedReferenceFrequency {
            tuner.referenceFrequency = ref
        }
        if let bpm = settings.lastUsedBPM {
            metronome.bpm = min(Metronome.maxBPM, max(Metronome.minBPM, bpm))
        }
    }

    /// Prevent a runaway other-service when switching cards.
    private func handleModeSwitch(to newMode: ToolkitMode) {
        if newMode != mode {
            if mode == .tuner { tuner.stop() }
            if mode == .metronome { metronome.stop() }
        }
        mode = newMode
    }
}

// MARK: - Mode

enum ToolkitMode: Hashable {
    case tuner, metronome

    var title: String {
        switch self {
        case .tuner: return "Tuner"
        case .metronome: return "Metronome"
        }
    }

    var icon: PraccyIcon {
        switch self {
        case .tuner: return .tuningFork
        case .metronome: return .metronome
        }
    }
}

// MARK: - Mode picker

private struct ModePicker: View {
    @Binding var mode: ToolkitMode
    let palette: AccentPalette
    let onSwitch: (ToolkitMode) -> Void

    var body: some View {
        HStack(spacing: 12) {
            card(for: .tuner)
            card(for: .metronome)
        }
    }

    @ViewBuilder
    private func card(for target: ToolkitMode) -> some View {
        let isActive = mode == target
        Button { onSwitch(target) } label: {
            VStack(spacing: 10) {
                PraccyIcon.view(
                    for: target.icon,
                    tint: isActive ? palette.onAccent : palette.accent,
                    size: 28
                )
                Text(target.title)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(isActive ? palette.onAccent : PraccyColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: PraccyRadius.card)
                    .fill(isActive ? palette.accent : Color.white)
            )
            .contentShape(RoundedRectangle(cornerRadius: PraccyRadius.card))
        }
        .buttonStyle(.praccyPress(shadow: isActive ? palette.shadow : PraccyColor.ink.opacity(0.12)))
        // Unscoped transaction-nil; value-scoped `.animation(nil)` lets the fill/foregroundStyle fade leak through.
        .transaction { $0.animation = nil }
        .accessibilityLabel(target.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Toolkit - violet") {
    let container = PraccySchema.makeContainer(inMemory: true)
    _ = UserSettings.current(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        ToolkitScreen(palette: .violet)
    }
    .modelContainer(container)
}

#endif
