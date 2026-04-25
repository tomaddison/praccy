import SwiftUI
import SwiftData

/// Bottom sheet listing tasks linked to the goal. Tapping a task dismisses and hands off via
/// `GoalsScreen`'s `onDismiss`.
struct GoalDetailSheet: View {
    let goal: Goal
    let palette: AccentPalette
    let onSelectTask: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider().overlay(palette.accent.opacity(0.18))
                tasksSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 28)
        }
        .background(palette.bg.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title)
                .font(PraccyFont.title)
                .tracking(-0.4)
                .foregroundStyle(PraccyColor.ink)
                .strikethrough(goal.isDone, color: PraccyColor.ink.opacity(0.5))
                .multilineTextAlignment(.leading)

            if !goal.subtitle.isEmpty {
                Text(goal.subtitle)
                    .font(PraccyFont.task)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 6) {
                PraccyIcon.view(for: .flag, tint: palette.accent, size: 12)
                Text(goal.dueLabel)
                    .font(PraccyFont.meta)
                    .foregroundStyle(palette.accent)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tasks

    @ViewBuilder
    private var tasksSection: some View {
        if sortedTasks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Linked tasks")
                    .praccyEyebrow()
                    .foregroundStyle(PraccyColor.ink60)
                Text("No tasks linked yet.")
                    .font(PraccyFont.task)
                    .foregroundStyle(PraccyColor.ink60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Linked tasks")
                    .praccyEyebrow()
                    .foregroundStyle(PraccyColor.ink60)

                VStack(spacing: 10) {
                    ForEach(sortedTasks, id: \.id) { task in
                        GoalTaskRow(
                            task: task,
                            palette: palette,
                            onSelect: { onSelectTask(task.id) }
                        )
                    }
                }
            }
        }
    }

    private var sortedTasks: [PracticeTask] {
        goal.tasks.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone && b.isDone }
            return a.createdAt < b.createdAt
        }
    }
}

// MARK: - Task row

/// Read-only; tap hands off to the shared task-detail sheet.
private struct GoalTaskRow: View {
    let task: PracticeTask
    let palette: AccentPalette
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                checkGlyph
                Text(task.title)
                    .font(PraccyFont.task)
                    .foregroundStyle(task.isDone ? PraccyColor.ink60 : PraccyColor.ink)
                    .strikethrough(task.isDone, color: PraccyColor.ink.opacity(0.5))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PraccyRadius.card)
                    .strokeBorder(palette.accent.opacity(0.12), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPress(offset: 2))
        .accessibilityLabel("\(task.title), \(task.isDone ? "done" : "not done")")
        .accessibilityAddTraits(.isButton)
    }

    private var checkGlyph: some View {
        ZStack {
            if task.isDone {
                Circle().fill(palette.accent)
                PraccyIcon.view(for: .check, tint: palette.onAccent, size: 10)
            } else {
                Circle().strokeBorder(palette.accent.opacity(0.4), lineWidth: 2)
            }
        }
        .frame(width: 22, height: 22)
        .padding(.top, 1)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Goal detail - with tasks") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    let goal = (try? container.mainContext.fetch(FetchDescriptor<Goal>()))?.first
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        if let goal {
            GoalDetailSheet(goal: goal, palette: .violet, onSelectTask: { _ in })
        } else {
            Text("No seeded goal")
        }
    }
    .modelContainer(container)
}
#endif
