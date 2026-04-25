import SwiftUI

/// White card below the week strip. "Today" or "MMM d" title; empty state when the day has no tasks.
struct SelectedDayCard: View {
    let selectedDate: Date
    let today: Date
    let tasks: [PracticeTask]
    let palette: AccentPalette
    var onSelectTask: (UUID) -> Void
    var onToggle: (PracticeTask) -> Void

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: today)
    }

    private var titleText: String {
        isToday ? "Today" : Self.titleFormatter.string(from: selectedDate)
    }

    private var totalMinutes: Int {
        tasks.reduce(0) { $0 + ($1.targetMinutes ?? 0) }
    }

    private var summaryText: String {
        let count = tasks.count
        let taskWord = count == 1 ? "task" : "tasks"
        if totalMinutes > 0 {
            return "\(count) \(taskWord) · \(totalMinutes) min"
        }
        return "\(count) \(taskWord)"
    }

    private var emptyCopy: String {
        isToday ? "Nothing on today." : "Rest day."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(PraccyColor.ink)
                if !tasks.isEmpty {
                    Text(summaryText)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                }
            }

            if tasks.isEmpty {
                Text(emptyCopy)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink45)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(tasks, id: \.id) { task in
                        CalendarTaskRow(
                            task: task,
                            accent: palette.accent,
                            onSelect: { onSelectTask(task.id) },
                            onToggle: { onToggle(task) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: PraccyColor.ink08)
    }
}

/// Lighter than Home's `TaskCard`: check + title + minutes only. Inlined; no third caller yet.
private struct CalendarTaskRow: View {
    let task: PracticeTask
    let accent: Color
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 14) {
                PraccyCheck(
                    isChecked: Binding(
                        get: { task.isDone },
                        set: { _ in }
                    ),
                    size: 26,
                    accent: accent,
                    onColor: .white,
                    onToggle: onToggle
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(PraccyColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(task.isDone, color: PraccyColor.ink45)
                        .opacity(task.isDone ? 0.5 : 1)

                    if let minutes = task.targetMinutes {
                        HStack(spacing: 5) {
                            PraccyIcon.view(for: .clock, tint: PraccyColor.ink45, size: 11)
                            Text("\(minutes) min")
                                .font(PraccyFont.meta)
                                .foregroundStyle(PraccyColor.ink45)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPress(offset: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [task.title]
        if let m = task.targetMinutes { parts.append("\(m) minutes") }
        parts.append(task.isDone ? "done" : "not done")
        return parts.joined(separator: ", ")
    }
}
