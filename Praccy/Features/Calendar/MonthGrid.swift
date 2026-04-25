import SwiftUI

/// 7-col month grid on a white card. Out-of-month padding keeps rows Mon→Sun aligned.
struct MonthGrid: View {
    /// Monday on or before the 1st of the month.
    let gridStart: Date
    let monthStart: Date
    let selectedDate: Date
    let today: Date
    let completedStarts: Set<Date>
    let dueStarts: Set<Date>
    let palette: AccentPalette
    /// Delta in whole months.
    var onShiftMonth: (Int) -> Void
    var onSelect: (Date) -> Void

    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private var rows: [[Date]] {
        let cal = Calendar.current
        // Six rows × 7 cols covers every month; trim empty tails.
        var all: [Date] = []
        for i in 0..<42 {
            if let d = cal.date(byAdding: .day, value: i, to: gridStart) {
                all.append(d)
            }
        }
        let rows = stride(from: 0, to: all.count, by: 7).map { Array(all[$0..<$0+7]) }
        return rows.filter { row in row.contains { isInMonth($0) } }
    }

    private func isInMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: monthStart, toGranularity: .month)
    }

    private static let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                monthNavButton(systemName: "chevron.left", label: "Previous month") {
                    onShiftMonth(-1)
                }
                Spacer(minLength: 0)
                Text(Self.monthLabelFormatter.string(from: monthStart))
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                monthNavButton(systemName: "chevron.right", label: "Next month") {
                    onShiftMonth(1)
                }
            }

            HStack(spacing: 6) {
                ForEach(Self.labels, id: \.self) { label in
                    Text(label)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { day in
                        WeekDayCell(
                            date: day,
                            isToday: Calendar.current.isDate(day, inSameDayAs: today),
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                            isCompleted: completedStarts.contains(
                                Calendar.current.startOfDay(for: day)
                            ),
                            hasDue: dueStarts.contains(
                                Calendar.current.startOfDay(for: day)
                            ),
                            isInMonth: isInMonth(day),
                            accent: palette.accent,
                            cellSize: 34,
                            onTap: { onSelect(day) }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccyWhiteCardShadow(palette)
    }

    @ViewBuilder
    private func monthNavButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(.subheadline, weight: .black))
                .foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPressFlat)
        .accessibilityLabel(label)
    }
}
