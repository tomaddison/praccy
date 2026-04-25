import SwiftUI
import UIKit

/// Tuner settings. Reference frequency lives here since it's set-and-forget per ensemble.
struct TunerSettingsSheet: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette

    private let minReference: Double = 400
    private let maxReference: Double = 500

    var body: some View {
        VStack(spacing: 22) {
            ReferenceStepper(
                tuner: tuner,
                palette: palette,
                minRef: minReference,
                maxRef: maxReference
            )
            PresetRow(tuner: tuner, palette: palette)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 28)
        .background(palette.bg.ignoresSafeArea())
    }
}

// MARK: - Reference stepper

private struct ReferenceStepper: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette
    let minRef: Double
    let maxRef: Double

    private var formatted: String {
        String(format: "%.0f Hz", tuner.referenceFrequency)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("A4 reference")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StepperButton(icon: .minus, palette: palette, enabled: tuner.referenceFrequency > minRef) {
                    tuner.referenceFrequency = max(minRef, (tuner.referenceFrequency - 1).rounded())
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                Text(formatted)
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(PraccyColor.ink)
                    .frame(width: 86)
                    .monospacedDigit()
                StepperButton(icon: .plus, palette: palette, enabled: tuner.referenceFrequency < maxRef) {
                    tuner.referenceFrequency = min(maxRef, (tuner.referenceFrequency + 1).rounded())
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow.opacity(0.35), offset: 3)
    }
}

// MARK: - Preset row

private struct PresetRow: View {
    @Bindable var tuner: Tuner
    let palette: AccentPalette

    private let presets: [(label: String, hz: Double)] = [
        ("415", 415),
        ("440", 440),
        ("442", 442)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .praccyEyebrow()
                .foregroundStyle(PraccyColor.ink60)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(presets, id: \.label) { preset in
                    presetChip(label: preset.label, hz: preset.hz)
                }
            }
        }
    }

    @ViewBuilder
    private func presetChip(label: String, hz: Double) -> some View {
        let isActive = abs(tuner.referenceFrequency - hz) < 0.5
        let subtitle: String = {
            switch hz {
            case 415: return "Baroque"
            case 440: return "Standard"
            case 442: return "Orchestra"
            default: return ""
            }
        }()

        Button {
            tuner.referenceFrequency = hz
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(isActive ? palette.onAccent : PraccyColor.ink)
                Text(subtitle)
                    .font(PraccyFont.meta)
                    .foregroundStyle(isActive ? palette.onAccent.opacity(0.85) : PraccyColor.ink60)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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
        }
        .buttonStyle(.praccyPress(offset: 2))
        .accessibilityLabel("\(label) hertz, \(subtitle)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tuner settings") {
    TunerSettingsSheet(tuner: Tuner(), palette: .violet)
}
#endif
