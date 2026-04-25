import SwiftUI
import SwiftData

/// `Identifiable` wrapper for `.sheet(item:)`; `UUID` isn't `Identifiable` natively.
private struct TaskSelection: Identifiable, Equatable {
    let id: UUID
}

/// Main shell. Owns tab selection, task-detail sheet, and settings sheet. Chrome reconfigures
/// when `UserSettings.role` changes. Uses `ViewBuilder` switches over `AnyView` to keep preview compile times short.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend
    @Environment(\.backendQueue) private var backendQueue
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [UserSettings]
    // Unfiltered on purpose: streak pill re-renders via @Query dependency; predicates mixing
    // `isDone` with optional-Date `!= nil` can hit runtime invalidation when the store wipes mid-query.
    @Query private var allTasks: [PracticeTask]

    @State private var studentTab: StudentTab = .home
    @State private var teacherTab: TeacherTab = .students
    @State private var taskSelection: TaskSelection? = nil
    @State private var showSettings: Bool = false
    @State private var showStreakSheet: Bool = false
    @State private var studentsPath: [StudentLink] = []

    private var palette: AccentPalette { .violet }
    private var role: UserRole { settingsRows.first?.role ?? .student }

    private var streak: Int {
        guard role == .student else { return 0 }
        return modelContext.currentStreak()
    }

    private var headerTitle: String? {
        switch role {
        case .student:
            switch studentTab {
            case .home: return nil
            case .calendar: return "Calendar"
            case .toolkit: return "Toolkit"
            case .goals: return "Goals"
            }
        case .teacher:
            switch teacherTab {
            case .students: return studentsPath.isEmpty ? "Students" : nil
            case .toolkit: return "Toolkit"
            }
        }
    }

    private var headerBackAction: (() -> Void)? {
        guard role == .teacher, teacherTab == .students, !studentsPath.isEmpty else {
            return nil
        }
        return { if !studentsPath.isEmpty { studentsPath.removeLast() } }
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                PraccyHeader(
                    role: role,
                    streak: streak,
                    palette: palette,
                    title: headerTitle,
                    onBack: headerBackAction,
                    onStreakTap: { showStreakSheet = true },
                    onSettings: { showSettings = true }
                )

                // Tab bar as a bottom safe-area inset; white fill bleeds through the home-indicator safe area.
                screenContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        tabBar
                            .frame(maxWidth: .infinity)
                            .background(Color.white.ignoresSafeArea(edges: .bottom))
                    }
            }

        }
        .sheet(item: $taskSelection) { selection in
            TaskDetailOverlay(taskID: selection.id, palette: palette)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) { SettingsSheet(palette: palette) }
        .sheet(isPresented: $showStreakSheet) {
            StreakSheet(streak: streak, palette: palette)
        }
        .task { await reconcileOnce() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await reconcileOnce() }
            }
        }
    }

    /// Pulls remote changes, applies them to SwiftData, and nudges the offline queue.
    /// Silent on failure; SwiftData's last-good snapshot stays on screen.
    private func reconcileOnce() async {
        if let changeSet = try? await backend.reconcile() {
            let coordinator = SyncCoordinator(modelContext: modelContext)
            coordinator.apply(changeSet)
        }
        await backendQueue?.drainIfNeeded()
    }

    // MARK: - Content

    @ViewBuilder
    private var screenContent: some View {
        switch role {
        case .student:
            switch studentTab {
            case .home:
                HomeScreen(
                    palette: palette,
                    onSelectTask: { taskSelection = TaskSelection(id: $0) },
                    onEnterCode: { showSettings = true }
                )
            case .calendar:
                CalendarScreen(
                    palette: palette,
                    onSelectTask: { taskSelection = TaskSelection(id: $0) }
                )
            case .toolkit: ToolkitScreen(palette: palette)
            case .goals:
                GoalsScreen(
                    palette: palette,
                    onSelectTask: { taskSelection = TaskSelection(id: $0) }
                )
            }
        case .teacher:
            switch teacherTab {
            case .students: StudentsScreen(palette: palette, path: $studentsPath)
            case .toolkit: ToolkitScreen(palette: palette)
            }
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        switch role {
        case .student:
            PraccyTabBar(
                tabs: StudentTab.allCases,
                selection: $studentTab,
                iconFor: \.icon,
                labelFor: \.title,
                palette: palette
            )
        case .teacher:
            PraccyTabBar(
                tabs: TeacherTab.allCases,
                selection: $teacherTab,
                iconFor: \.icon,
                labelFor: \.title,
                palette: palette
            )
        }
    }

}

#if DEBUG
#Preview("Root - fresh student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    return RootView()
        .modelContainer(container)
}

#Preview("Root - seeded student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return RootView()
        .modelContainer(container)
}

#Preview("Root - seeded teacher") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    return RootView()
        .modelContainer(container)
}

#Preview("Root - fresh teacher") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.role = .teacher
    return RootView()
        .modelContainer(container)
}
#endif
