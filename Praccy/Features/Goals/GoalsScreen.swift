import SwiftUI
import SwiftData
import UIKit

/// Student-side read-only list of teacher-authored goals. Card tap opens `GoalDetailSheet`;
/// task-row tap inside dismisses and hands off to the shared task-detail sheet.
struct GoalsScreen: View {
    @Environment(\.modelContext) private var modelContext

    let palette: AccentPalette
    var onSelectTask: (UUID) -> Void

    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    @State private var goalSelection: GoalSelection? = nil
    @State private var pendingTaskID: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if goals.isEmpty {
                    EmptyGoalsState(palette: palette)
                        .padding(.top, 36)
                } else {
                    VStack(spacing: 10) {
                        ForEach(goals, id: \.id) { goal in
                            GoalCard(
                                goal: goal,
                                palette: palette,
                                onOpen: { goalSelection = GoalSelection(id: goal.id) },
                                onToggle: { toggleCompletion(goal) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .sheet(
            item: $goalSelection,
            onDismiss: {
                if let id = pendingTaskID {
                    pendingTaskID = nil
                    DispatchQueue.main.async { onSelectTask(id) }
                }
            }
        ) { selection in
            if let goal = goals.first(where: { $0.id == selection.id }) {
                GoalDetailSheet(
                    goal: goal,
                    palette: palette,
                    onSelectTask: { taskID in
                        pendingTaskID = taskID
                        goalSelection = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(palette.bg)
            }
        }
    }

    private func toggleCompletion(_ goal: Goal) {
        let willComplete = !goal.isDone
        goal.isDone.toggle()
        goal.completedAt = goal.isDone ? .now : nil
        try? modelContext.save()

        if willComplete {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

private struct GoalSelection: Identifiable, Equatable {
    let id: UUID
}

// MARK: - Empty state

/// Shown when no goals exist.
private struct EmptyGoalsState: View {
    let palette: AccentPalette

    var body: some View {
        VStack(spacing: 18) {
            PraccyMascot(size: 104, mood: .happy, accent: palette.accent)
            VStack(spacing: 6) {
                Text("No goals yet")
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(PraccyColor.ink)
                Text("Your teacher will add goals here.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Goals - seeded student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        GoalsScreen(palette: .violet, onSelectTask: { _ in })
    }
    .modelContainer(container)
}

#Preview("Goals - empty state") {
    let container = PraccySchema.makeContainer(inMemory: true)
    _ = UserSettings.current(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        GoalsScreen(palette: .violet, onSelectTask: { _ in })
    }
    .modelContainer(container)
}
#endif
