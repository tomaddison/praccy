import SwiftUI
import SwiftData
import UIKit

/// Drone-tuner surface. Reference frequency lives behind the cog (`TunerSettingsSheet`).
struct TunerView: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette
    /// Optional: first run may race the settings-row insert; the cog opens without persistence until the row exists.
    var settings: UserSettings?

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 22) {
            NotePicker(tuner: tuner, palette: palette)
            HStack(spacing: 12) {
                ReferencePillButton(tuner: tuner, palette: palette) { showSettings = true }
                OctaveStepper(tuner: tuner, palette: palette)
            }
            PlayButton(tuner: tuner, palette: palette)
        }
        .sheet(isPresented: $showSettings) {
            TunerSettingsSheet(tuner: tuner, palette: palette)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: tuner.note) { persistNote() }
        .onChange(of: tuner.octave) { persistOctave() }
        .onChange(of: tuner.referenceFrequency) { persistReference() }
    }

    private func persistNote() {
        settings?.lastUsedTunerNote = tuner.note.rawValue
    }

    private func persistOctave() {
        settings?.lastUsedTunerOctave = tuner.octave
    }

    private func persistReference() {
        settings?.lastUsedReferenceFrequency = tuner.referenceFrequency
    }
}

// MARK: - Reference pitch pill

/// Compact label button showing the current A-reference (e.g. `A 440`).
/// Sits to the left of the octave stepper; tap opens `TunerSettingsSheet`.
private struct ReferencePillButton: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("A \(Int(tuner.referenceFrequency))")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .monospacedDigit()
                .frame(minHeight: 36)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: PraccyRadius.card)
                        .strokeBorder(palette.accent.opacity(0.12), lineWidth: 1.5)
                }
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel("Reference pitch, A \(Int(tuner.referenceFrequency)) hertz")
        .accessibilityHint("Opens tuner settings")
    }
}

// MARK: - Note picker

private struct NotePicker: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette

    // Two rows of six so the chromatic row reads left-to-right without
    // getting too wide on small devices.
    private let rows: [[TunerNote]] = [
        [.c, .cSharp, .d, .dSharp, .e, .f],
        [.fSharp, .g, .gSharp, .a, .aSharp, .b]
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(rows[row], id: \.self) { note in
                        NotePill(note: note, isActive: tuner.note == note, palette: palette) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            tuner.note = note
                        }
                    }
                }
            }
        }
    }
}

private struct NotePill: View {
    let note: TunerNote
    let isActive: Bool
    let palette: AccentPalette
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(note.rawValue)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(isActive ? palette.onAccent : PraccyColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.pill)
                        .fill(isActive ? palette.accent : Color.white)
                )
                .overlay {
                    if !isActive {
                        RoundedRectangle(cornerRadius: PraccyRadius.pill)
                            .strokeBorder(palette.accent.opacity(0.15), lineWidth: 1.5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: PraccyRadius.pill))
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel(note.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Octave stepper

private struct OctaveStepper: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette

    private let minOctave = 2
    private let maxOctave = 6

    var body: some View {
        HStack(spacing: 0) {
            Text("Octave")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            StepperButton(icon: .minus, palette: palette, enabled: tuner.octave > minOctave) {
                guard tuner.octave > minOctave else { return }
                tuner.octave -= 1
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .accessibilityLabel("Decrease octave")
            Text("\(tuner.octave)")
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
                .frame(width: 44)
                .monospacedDigit()
                .accessibilityLabel("Octave \(tuner.octave)")
            StepperButton(icon: .plus, palette: palette, enabled: tuner.octave < maxOctave) {
                guard tuner.octave < maxOctave else { return }
                tuner.octave += 1
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .accessibilityLabel("Increase octave")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PraccyRadius.card)
                .strokeBorder(palette.accent.opacity(0.12), lineWidth: 1.5)
        }
    }
}

struct StepperButton: View {
    let icon: PraccyIcon
    let palette: AccentPalette
    let enabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            PraccyIcon.view(for: icon, tint: palette.onAccent, size: 14)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(enabled ? palette.accent : palette.accent.opacity(0.3))
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPressFlat)
        .disabled(!enabled)
        .accessibilityLabel(icon == .plus ? "Increase" : "Decrease")
    }
}

// MARK: - Play button

private struct PlayButton: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            tuner.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                    .fill(palette.accent)
                HStack(spacing: 10) {
                    PraccyIcon.view(
                        for: tuner.isPlaying ? .stop : .speakerWave,
                        tint: palette.onAccent,
                        size: 18
                    )
                    Text(tuner.isPlaying ? "Stop" : "Play")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(palette.onAccent)
                }
                .padding(.vertical, 16)
                .animation(nil, value: tuner.isPlaying)
            }
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.praccyPress(shadow: palette.shadow))
        .accessibilityLabel(tuner.isPlaying ? "Stop drone" : "Play drone")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tuner - violet") {
    let container = PraccySchema.makeContainer(inMemory: true)
    _ = UserSettings.current(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        TunerView(
            tuner: Tuner(),
            palette: .violet,
            settings: UserSettings.current(in: container.mainContext)
        )
        .padding(18)
    }
    .modelContainer(container)
}
#endif
