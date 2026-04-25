import SwiftUI

/// Playback row used inside `RecordingCard` once a take exists.
struct PlaybackRow: View {
    let recording: Recording
    let palette: AccentPalette
    @Bindable var playback: PlaybackController
    let onRerecord: () -> Void
    let onDelete: () -> Void

    private static let pattern: [CGFloat] = [
        0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.3, 0.7,
        0.5, 0.6, 0.4, 0.8, 0.5, 0.7, 0.4, 0.6
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button(action: { playback.toggle() }) {
                    ZStack {
                        Circle().fill(palette.accent)
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.praccyPress(offset: 2))
                .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")

                WaveformBars(
                    pattern: Self.pattern,
                    progress: playback.progress,
                    tint: palette.accent
                )
                .frame(height: 28)
                .frame(maxWidth: .infinity)

                Text(Self.format(recording.duration))
                    .font(PraccyFont.meta)
                    .foregroundStyle(palette.accent)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card - 8))
            .praccySolidShadow(color: PraccyColor.ink10, offset: 3)

            Button(action: onRerecord) {
                Text("Re-record")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.card - 8)
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    )
            }
            .buttonStyle(.praccyPress(offset: 2))
            .accessibilityLabel("Re-record")

            Button(action: onDelete) {
                Text("Delete recording")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.card - 8)
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    )
            }
            .buttonStyle(.praccyPress(offset: 2))
            .accessibilityLabel("Delete recording")
            .accessibilityHint("Removes this take. Confirmation required.")
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Static bars with a progress overlay; no scrubbing yet.
private struct WaveformBars: View {
    let pattern: [CGFloat]
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<pattern.count, id: \.self) { i in
                    let played = Double(i + 1) / Double(pattern.count) <= progress
                    Capsule(style: .continuous)
                        .fill(tint.opacity(played ? 1 : 0.35))
                        .frame(height: geo.size.height * pattern[i])
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
