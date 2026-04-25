import SwiftUI

/// Goal row card. Tap opens `GoalDetailSheet`; check toggles completion with confetti.
struct GoalCard: View {
    let goal: Goal
    let palette: AccentPalette
    let onOpen: () -> Void
    let onToggle: () -> Void

    @State private var burst: UUID? = nil

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 14) {
                tickSlot
                titleBlock
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
            .clipShape(RoundedRectangle(cornerRadius: PraccyRadius.card))
            .contentShape(RoundedRectangle(cornerRadius: PraccyRadius.card))
        }
        .buttonStyle(goal.isDone
            ? .praccyPress(shadow: .clear, offset: 3)
            : .praccyWhiteCardPress(palette))
        .opacity(goal.isDone ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardA11yLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Pieces

    private var tickSlot: some View {
        ZStack {
            PraccyCheck(
                isChecked: Binding(
                    get: { goal.isDone },
                    // `onToggle` mutates the model; no-op set prevents double-flip.
                    set: { _ in }
                ),
                size: 30,
                accent: palette.accent,
                onToggle: handleTick
            )
            if burst != nil {
                ConfettiBurst(accent: palette.accent) { burst = nil }
                    .frame(width: 60, height: 60)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, 2)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goal.title)
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
                .multilineTextAlignment(.leading)
                .strikethrough(goal.isDone, color: PraccyColor.ink)

            if !goal.subtitle.isEmpty {
                Text(goal.subtitle)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                PraccyIcon.view(for: .flag, tint: palette.accent, size: 11)
                Text(goal.dueLabel)
                    .font(PraccyFont.meta)
                    .foregroundStyle(palette.accent)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardA11yLabel: String {
        let status = goal.isDone ? "completed" : "in progress"
        var parts = [goal.title]
        if !goal.subtitle.isEmpty { parts.append(goal.subtitle) }
        parts.append(goal.dueLabel)
        parts.append(status)
        return parts.joined(separator: ", ")
    }

    private func handleTick() {
        if !goal.isDone { burst = UUID() }
        onToggle()
    }
}
