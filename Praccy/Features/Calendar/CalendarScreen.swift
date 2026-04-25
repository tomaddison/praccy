import SwiftUI
import SwiftData

/// Practice-history month grid: dots on due days, ticks on completed days.
/// Fires `onSelectTask(id)` to open the same detail overlay Home uses.
struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext

    let palette: AccentPalette
    var onSelectTask: (UUID) -> Void

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var displayMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: .now)
        return cal.date(from: comps) ?? .now
    }()

    private let today: Date = Calendar.current.startOfDay(for: .now)

    private var monthStart: Date { displayMonth }

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    private var monthGridStart: Date {
        CalendarScreen.mondayOnOrBefore(monthStart)
    }

    /// Wide enough to cover the month grid's top/bottom rows that spill into adjacent months.
    private var visibleRange: DateInterval {
        let end = Calendar.current.date(byAdding: .day, value: 42, to: monthGridStart) ?? monthEnd
        return DateInterval(start: monthGridStart, end: end)
    }

    private var completedStarts: Set<Date> {
        modelContext.completedDayStarts(in: visibleRange)
    }

    private var dueStarts: Set<Date> {
        modelContext.dueDayStarts(in: visibleRange)
    }

    private var selectedTasks: [PracticeTask] {
        modelContext.tasks(on: selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthGrid(
                    gridStart: monthGridStart,
                    monthStart: monthStart,
                    selectedDate: selectedDate,
                    today: today,
                    completedStarts: completedStarts,
                    dueStarts: dueStarts,
                    palette: palette,
                    onShiftMonth: shiftMonth(by:),
                    onSelect: { selectedDate = Calendar.current.startOfDay(for: $0) }
                )

                SelectedDayCard(
                    selectedDate: selectedDate,
                    today: today,
                    tasks: selectedTasks,
                    palette: palette,
                    onSelectTask: onSelectTask,
                    onToggle: toggleCompletion(_:)
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    private func shiftMonth(by delta: Int) {
        let cal = Calendar.current
        displayMonth = cal.date(byAdding: .month, value: delta, to: displayMonth) ?? displayMonth
    }

    private func toggleCompletion(_ task: PracticeTask) {
        task.isDone.toggle()
        task.completedAt = task.isDone ? .now : nil
        try? modelContext.save()
    }
}

// MARK: - Date helpers (view-layer only)

extension CalendarScreen {
    /// Monday-anchored to keep Mon→Sun regardless of device locale.
    fileprivate static var weekCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = .current
        return cal
    }

    static func weekInterval(containing date: Date) -> DateInterval {
        let cal = weekCalendar
        return cal.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: cal.startOfDay(for: date), duration: 7 * 24 * 3600)
    }

    static func mondayOnOrBefore(_ date: Date) -> Date {
        weekInterval(containing: date).start
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Calendar - seeded student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        CalendarScreen(palette: .violet, onSelectTask: { _ in })
    }
    .modelContainer(container)
}
#endif
