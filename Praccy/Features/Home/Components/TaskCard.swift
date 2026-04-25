import SwiftUI

/// Self-owns the completion confetti so state doesn't bubble up to the screen.
struct TaskCard: View {
    let task: PracticeTask
    let palette: AccentPalette
    let onSelect: () -> Void
    let onToggle: () -> Void

    @State private var burst: UUID? = nil

    var body: some View {
        Button(action: onSelect) {
            cardBody
        }
        .buttonStyle(.praccyWhiteCardPress(palette))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var cardBody: some View {
        HStack(alignment: .center, spacing: 6) {
            PraccyCheck(
                isChecked: Binding(
                    get: { task.isDone },
                    // `onToggle` mutates the model; no-op set prevents double-flip.
                    set: { _ in }
                ),
                size: 28,
                accent: palette.accent,
                onToggle: handleToggle
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .strikethrough(task.isDone, color: PraccyColor.ink)

                if !task.isDone, hasInfoRow {
                    infoRow
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .opacity(task.isDone ? 0.4 : 1)
        .overlay(alignment: .topLeading) {
            if burst != nil {
                ConfettiBurst(accent: .white) { burst = nil }
                    .frame(width: 64, height: 64)
                    .offset(x: 16, y: 14)
                    .allowsHitTesting(false)
            }
        }
    }

    private var hasInfoRow: Bool {
        task.targetMinutes != nil || task.hasAudio
    }

    @ViewBuilder
    private var infoRow: some View {
        HStack(spacing: 8) {
            if let minutes = task.targetMinutes {
                TaskInfoChip(palette: palette) {
                    PraccyIcon.view(for: .clock, tint: palette.accent, size: 11)
                    Text("\(minutes) min")
                }
            }
            if task.hasAudio {
                TaskInfoChip(palette: palette) {
                    PraccyIcon.view(for: .mic, tint: palette.accent, size: 11)
                }
            }
        }
    }

    private func handleToggle() {
        if !task.isDone {
            burst = UUID()
        }
        onToggle()
    }

    private var accessibilityLabel: String {
        var parts: [String] = [task.title]
        if let m = task.targetMinutes { parts.append("\(m) minutes") }
        if task.hasAudio { parts.append("recording attached") }
        parts.append(task.isDone ? "done" : "not done")
        return parts.joined(separator: ", ")
    }
}

private struct TaskInfoChip<Content: View>: View {
    let palette: AccentPalette
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 5) {
            content()
        }
        .font(PraccyFont.meta)
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(palette.accent.opacity(0.12), in: Capsule())
    }
}
