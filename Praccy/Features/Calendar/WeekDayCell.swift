import SwiftUI

/// Month-grid day cell. Day-number/check glyph, due dot, today outline, selected fill.
struct WeekDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let isCompleted: Bool
    let hasDue: Bool
    /// False for padding cells outside the displayed month: faded and non-interactive.
    let isInMonth: Bool
    let accent: Color
    let cellSize: CGFloat
    var onTap: () -> Void

    private static let accessibilityFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(accent)
                    .opacity(isSelected ? 1 : 0)

                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(accent, lineWidth: 2)
                    .opacity(isToday && !isSelected ? 1 : 0)

                if isCompleted {
                    PraccyIcon.view(
                        for: .check,
                        tint: isSelected ? Color.white : accent,
                        size: cellSize * 0.44
                    )
                } else {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(glyphColor)
                }

                if hasDue && !isCompleted {
                    Circle()
                        .fill(isSelected ? Color.white : accent)
                        .frame(width: 4, height: 4)
                        .offset(y: cellSize * 0.32)
                }
            }
            .frame(width: cellSize, height: cellSize)
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.praccyPressFlat)
        .disabled(!isInMonth)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var glyphColor: Color {
        if isSelected { return .white }
        if !isInMonth { return PraccyColor.ink.opacity(0.25) }
        return PraccyColor.ink
    }

    private var accessibilityLabel: String {
        var parts = [Self.accessibilityFormatter.string(from: date)]
        if isToday { parts.append("today") }
        if hasDue { parts.append("has task") }
        if isCompleted { parts.append("practised") }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview("Week day cell - states") {
    let accent = AccentPalette.violet.accent
    return HStack(spacing: 10) {
        WeekDayCell(
            date: .now, isToday: false, isSelected: false,
            isCompleted: false, hasDue: false, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
        WeekDayCell(
            date: .now, isToday: true, isSelected: false,
            isCompleted: false, hasDue: false, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
        WeekDayCell(
            date: .now, isToday: false, isSelected: false,
            isCompleted: false, hasDue: true, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
        WeekDayCell(
            date: .now, isToday: false, isSelected: true,
            isCompleted: false, hasDue: true, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
        WeekDayCell(
            date: .now, isToday: false, isSelected: false,
            isCompleted: true, hasDue: false, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
        WeekDayCell(
            date: .now, isToday: true, isSelected: true,
            isCompleted: true, hasDue: false, isInMonth: true,
            accent: accent, cellSize: 40, onTap: {}
        )
    }
    .padding(20)
    .background(Color.white)
}
#endif
