import SwiftUI
import SwiftData
import UIKit

/// Accent-pattern metronome surface. Volume follows the device; no settings sheet.
struct MetronomeView: View {
    @Bindable var metronome: Metronome
    let palette: AccentPalette
    var settings: UserSettings?

    // Inline keypad: system numberPad has no Return key and lifts the tab bar / distorts the running click.
    @State private var bpmEditing = false
    /// 0 = no digit typed; readout falls back to `metronome.bpm`.
    @State private var bpmDraft: Int = 0

    var body: some View {
        VStack(spacing: 22) {
            BPMReadout(
                metronome: metronome,
                palette: palette,
                editingDraft: bpmEditing ? bpmDraft : nil,
                onTap: beginBPMEdit
            )

            if bpmEditing {
                BPMKeypad(
                    draft: $bpmDraft,
                    palette: palette,
                    onDone: commitBPMEdit
                )
            } else {
                BeatRow(metronome: metronome, palette: palette)
                PraccyTickSlider(
                    value: tempoBinding,
                    in: Metronome.minBPM...Metronome.maxBPM,
                    palette: palette
                )
                PlayAndTapRow(metronome: metronome, palette: palette)
            }
        }
        .onChange(of: metronome.bpm) { persistBPM() }
    }

    private var tempoBinding: Binding<Int> {
        Binding(get: { metronome.bpm }, set: { metronome.bpm = $0 })
    }

    private func beginBPMEdit() {
        bpmDraft = 0
        bpmEditing = true
    }

    private func commitBPMEdit() {
        if bpmDraft > 0 {
            metronome.bpm = min(Metronome.maxBPM, max(Metronome.minBPM, bpmDraft))
        }
        bpmEditing = false
    }

    private func persistBPM() {
        settings?.lastUsedBPM = metronome.bpm
    }
}

// MARK: - BPM readout

/// `editingDraft`: `nil` = not editing; `0` = editing, no digit typed
/// (shows live `metronome.bpm` faded); `>0` = typed draft.
private struct BPMReadout: View {
    @Bindable var metronome: Metronome
    let palette: AccentPalette
    /// `nil` = not editing; `0` = editing, no digit typed; `>0` = typed
    /// draft value.
    var editingDraft: Int?
    var onTap: () -> Void

    private var displayedValue: Int {
        if let draft = editingDraft, draft > 0 { return draft }
        return metronome.bpm
    }

    private var isPlaceholder: Bool {
        editingDraft == 0
    }

    private var markingBPM: Int {
        if let draft = editingDraft, draft > 0 {
            return min(Metronome.maxBPM, max(Metronome.minBPM, draft))
        }
        return metronome.bpm
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(displayedValue)")
                .font(PraccyFont.display)
                .tracking(-2)
                .foregroundStyle(PraccyColor.ink)
                .opacity(isPlaceholder ? 0.35 : 1)
                .monospacedDigit()
                .minimumScaleFactor(0.85)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    if editingDraft == nil { onTap() }
                }

            Text(Metronome.tempoMarking(for: markingBPM))
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metronome.bpm) BPM, \(metronome.tempoMarking)")
        .accessibilityHint("Tap to enter a tempo")
    }
}

// MARK: - BPM keypad

/// Custom 3×4 numeric pad; no system keyboard.
private struct BPMKeypad: View {
    @Binding var draft: Int
    let palette: AccentPalette
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                digit(1); digit(2); digit(3)
            }
            HStack(spacing: 10) {
                digit(4); digit(5); digit(6)
            }
            HStack(spacing: 10) {
                digit(7); digit(8); digit(9)
            }
            HStack(spacing: 10) {
                backspace
                digit(0)
                done
            }
        }
    }

    private func digit(_ n: Int) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            append(n)
        } label: {
            Text("\(n)")
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .fill(Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .strokeBorder(palette.accent.opacity(0.15), lineWidth: 1.5)
                }
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel("\(n)")
    }

    private var backspace: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            draft /= 10
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(PraccyColor.ink60)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .fill(Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .strokeBorder(palette.accent.opacity(0.15), lineWidth: 1.5)
                }
        }
        .buttonStyle(.praccyPressFlat)
        .disabled(draft == 0)
        .opacity(draft == 0 ? 0.4 : 1)
        .accessibilityLabel("Delete")
    }

    private var done: some View {
        Button(action: onDone) {
            Text("Done")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .fill(palette.accent)
                )
        }
        .buttonStyle(.praccyPress(shadow: palette.shadow))
        .accessibilityLabel("Done")
    }

    private func append(_ digit: Int) {
        let next = draft * 10 + digit
        guard next <= 999 else { return }
        draft = next
    }
}

// MARK: - Beat row

private struct BeatRow: View {
    @Bindable var metronome: Metronome
    let palette: AccentPalette

    var body: some View {
        HStack(spacing: 12) {
            StepperButton(
                icon: .minus,
                palette: palette,
                enabled: metronome.beats.count > Metronome.minBeats
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(PraccyAnimation.bounce) {
                    metronome.removeBeat()
                }
            }

            // `.position(...)` inside a ZStack animates each existing
            // dot's shift when siblings are added or removed.
            GeometryReader { geo in
                let count = max(1, metronome.beats.count)
                let slot = geo.size.width / CGFloat(count)
                // Leave a little breathing room between dots so adjacent
                // circles don't touch when the row is densely packed.
                let dotSize = min(32, max(12, slot - 8))
                ZStack(alignment: .topLeading) {
                    ForEach(metronome.beats.indices, id: \.self) { index in
                        BeatDot(
                            beat: metronome.beats[index],
                            isActive: metronome.isPlaying && metronome.currentBeatIndex == index,
                            palette: palette,
                            size: dotSize
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            metronome.toggleBeat(at: index)
                        }
                        .frame(width: slot, height: 44)
                        .position(x: slot * (CGFloat(index) + 0.5), y: 22)
                    }
                }
                .frame(width: geo.size.width, height: 44)
                .animation(PraccyAnimation.bounce, value: count)
            }
            .frame(height: 44)

            StepperButton(
                icon: .plus,
                palette: palette,
                enabled: metronome.beats.count < Metronome.maxBeats
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(PraccyAnimation.bounce) {
                    metronome.addBeat()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PraccyRadius.card)
                .strokeBorder(palette.accent.opacity(0.12), lineWidth: 1.5)
        }
    }
}

private struct BeatDot: View {
    let beat: MetronomeBeat
    let isActive: Bool
    let palette: AccentPalette
    let size: CGFloat
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(PraccyAnimation.bounce) { onTap() }
        } label: {
            Circle()
                .fill(beat == .down ? palette.accent : Color.white)
                .overlay(
                    Circle()
                        .strokeBorder(palette.accent.opacity(0.5), lineWidth: 2)
                        .opacity(beat == .up ? 1 : 0)
                )
                .frame(width: size, height: size)
                .scaleEffect(scale, anchor: .center)
                .opacity(reduceMotion && isActive ? 0.65 : 1)
                .animation(activeAnimation, value: isActive)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel(beat == .down ? "Downbeat" : "Upbeat")
        .accessibilityHint("Tap to toggle")
    }

    private var scale: CGFloat {
        let base: CGFloat = beat == .down ? 1.0 : 0.75
        return isActive && !reduceMotion ? base * 1.25 : base
    }

    /// Reduce-motion uses a brief opacity pulse instead of a spring.
    private var activeAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.08) }
        return isActive ? PraccyAnimation.beatAttack : PraccyAnimation.beatSettle
    }
}

// MARK: - Play + Tap row

/// Tap on the left, Play on the right. Play takes ~2/3 of the row
/// because it's the primary CTA and lives where most thumbs naturally
/// rest. Tap is secondary (white pill with accent border).
private struct PlayAndTapRow: View {
    @Bindable var metronome: Metronome
    let palette: AccentPalette

    @State private var tapPulse = false

    var body: some View {
        HStack(spacing: 12) {
            tapButton
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            playButton
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
        }
    }

    private var tapButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            metronome.tapTempo()
            tapPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                tapPulse = false
            }
        } label: {
            Text("Tap")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .fill(Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                        .strokeBorder(palette.accent.opacity(tapPulse ? 0.8 : 0.25), lineWidth: 2)
                }
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel("Tap tempo")
    }

    private var playButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            metronome.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                    .fill(palette.accent)
                HStack(spacing: 10) {
                    PraccyIcon.view(
                        for: metronome.isPlaying ? .stop : .play,
                        tint: palette.onAccent,
                        size: 18
                    )
                    Text(metronome.isPlaying ? "Stop" : "Play")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(palette.onAccent)
                }
                .padding(.vertical, 16)
                .transaction { $0.animation = nil }
            }
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.praccyPress(shadow: palette.shadow))
        .transaction { $0.animation = nil }
        .accessibilityLabel(metronome.isPlaying ? "Stop metronome" : "Start metronome")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Metronome - violet") {
    let container = PraccySchema.makeContainer(inMemory: true)
    _ = UserSettings.current(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        MetronomeView(
            metronome: Metronome(),
            palette: .violet,
            settings: UserSettings.current(in: container.mainContext)
        )
        .padding(18)
    }
    .modelContainer(container)
}
#endif
