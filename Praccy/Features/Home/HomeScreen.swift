import SwiftUI
import SwiftData
import UIKit

/// Student Home (Today). Teacher-assigned only; no "Add" affordance.
/// `RootView` owns the task-detail overlay and receives the selected id via callback.
struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext

    let palette: AccentPalette
    var onSelectTask: (UUID) -> Void
    var onEnterCode: () -> Void = {}

    // SwiftData's #Predicate can't reach `rawValue` on a Codable enum stored on an @Model,
    // so fetch everything and filter in Swift (lists are tiny).
    @Query private var allTeacherLinks: [TeacherLink]
    // @Query keeps the view reactive to task mutations; today's slice is computed via
    // ModelContext.tasks(on:) so the date-window filter lives in one place.
    @Query private var allTasksObserve: [PracticeTask]

    private var hasActiveTeacher: Bool {
        allTeacherLinks.contains { $0.state == .active }
    }

    private var todaysTasks: [PracticeTask] {
        _ = allTasksObserve   // re-render when tasks change
        return modelContext.tasks(on: .now)
    }

    var body: some View {
        if !hasActiveTeacher {
            PreLinkedHomeState(palette: palette, onEnterCode: onEnterCode)
        } else {
            todayContent
        }
    }

    // MARK: - Linked-state body

    @ViewBuilder
    private var todayContent: some View {
        let tasks = todaysTasks
        let todo = tasks.filter { !$0.isDone }
        let done = tasks.filter { $0.isDone }
        let total = tasks.count
        let progress = total == 0 ? 0 : Double(done.count) / Double(total)

        ScrollView {
            VStack(spacing: 0) {
                MascotHero(progress: progress, palette: palette)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                ProgressCard(
                    palette: palette,
                    done: done.count,
                    total: total,
                    progress: progress
                )
                .padding(.horizontal, 18)

                if total == 0 {
                    WaitingForTeacherCard(palette: palette)
                        .padding(.horizontal, 18)
                        .padding(.top, 24)
                } else {
                    if !todo.isEmpty {
                        TodoSection(
                            tasks: todo,
                            palette: palette,
                            onSelect: onSelectTask,
                            onToggle: toggleCompletion(_:)
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 24)
                    }

                    if !done.isEmpty {
                        DoneSection(
                            tasks: done,
                            palette: palette,
                            onSelect: onSelectTask,
                            onToggle: toggleCompletion(_:)
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func toggleCompletion(_ task: PracticeTask) {
        let willComplete = !task.isDone
        task.isDone.toggle()
        task.completedAt = task.isDone ? .now : nil
        try? modelContext.save()

        // Un-ticking must never decrease `bestStreak`; a checkbox undo can't erase a high.
        if willComplete {
            let current = modelContext.currentStreak()
            let settings = UserSettings.current(in: modelContext)
            if current > settings.bestStreak {
                settings.bestStreak = current
                try? modelContext.save()
            }
        }

        if willComplete {
            let allDone = modelContext.tasks(on: .now).allSatisfy { $0.isDone }
            if allDone {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - Sections (tightly coupled to HomeScreen body)

private struct TodoSection: View {
    let tasks: [PracticeTask]
    let palette: AccentPalette
    let onSelect: (UUID) -> Void
    let onToggle: (PracticeTask) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("To do")
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(PraccyColor.ink)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            ForEach(tasks, id: \.id) { task in
                TaskCard(
                    task: task,
                    palette: palette,
                    onSelect: { onSelect(task.id) },
                    onToggle: { onToggle(task) }
                )
            }
        }
    }
}

private struct DoneSection: View {
    let tasks: [PracticeTask]
    let palette: AccentPalette
    let onSelect: (UUID) -> Void
    let onToggle: (PracticeTask) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                expanded.toggle()
            } label: {
                HStack {
                    Text("Done · \(tasks.count)")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(PraccyColor.ink45)
                    Spacer()
                    PraccyIcon.view(for: .chevronDown, tint: PraccyColor.ink45, size: 14)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.praccyPress)
            .accessibilityLabel("Done, \(tasks.count) task\(tasks.count == 1 ? "" : "s"). \(expanded ? "Hide" : "Show")")

            if expanded {
                VStack(spacing: 10) {
                    ForEach(tasks, id: \.id) { task in
                        TaskCard(
                            task: task,
                            palette: palette,
                            onSelect: { onSelect(task.id) },
                            onToggle: { onToggle(task) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Home - seeded student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        HomeScreen(
            palette: .violet,
            onSelectTask: { _ in }
        )
    }
    .modelContainer(container)
}

#Preview("Home - pre-linked student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.role = .student
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        HomeScreen(
            palette: .violet,
            onSelectTask: { _ in }
        )
    }
    .modelContainer(container)
}

#Preview("Home - no tasks today") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.role = .student
    let teacher = TeacherLink(
        teacherDisplayName: "Claire",
        remoteTeacherID: "preview-teacher",
        state: .active
    )
    container.mainContext.insert(teacher)
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        HomeScreen(
            palette: .violet,
            onSelectTask: { _ in }
        )
    }
    .modelContainer(container)
}
#endif
