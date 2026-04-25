import SwiftUI
import SwiftData

private struct TaskSelection: Identifiable, Equatable {
    let id: UUID
}

/// Detail screen for a roster row. Composers present as sheets; task-row taps open the shared `TaskDetailOverlay`.
struct StudentDetailScreen: View {
    let link: StudentLink
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend
    @Environment(\.dismiss) private var dismiss

    @State private var showAddGoal: Bool = false
    @State private var showAssignTask: Bool = false
    @State private var taskSelection: TaskSelection?
    @State private var goalPendingRemoval: Goal?
    @State private var showUnlinkAlert: Bool = false
    @State private var unlinkError: String?

    private var goals: [Goal] { modelContext.goals(for: link) }
    private var tasks: [PracticeTask] { modelContext.assignedTasks(for: link) }
    private var openTasks: [PracticeTask] { tasks.filter { !$0.isDone } }
    private var doneTasks: [PracticeTask] { tasks.filter { $0.isDone } }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                header
                tasksSection
                goalsSection
                unlinkButton
                if let unlinkError {
                    Text(unlinkError)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.warning)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddGoal) {
            AddGoalForStudentSheet(link: link, palette: palette)
        }
        .sheet(isPresented: $showAssignTask) {
            AssignTaskSheet(link: link, palette: palette)
        }
        .sheet(item: $taskSelection) { selection in
            TaskDetailOverlay(taskID: selection.id, palette: palette)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Remove goal?",
            isPresented: Binding(
                get: { goalPendingRemoval != nil },
                set: { if !$0 { goalPendingRemoval = nil } }
            ),
            presenting: goalPendingRemoval
        ) { goal in
            Button("Remove", role: .destructive) {
                Task { await removeGoal(goal) }
            }
            Button("Keep", role: .cancel) { goalPendingRemoval = nil }
        } message: { goal in
            Text("Tasks laddering up to \(goal.title) stay in \(link.studentDisplayName)'s history.")
        }
        .alert(
            "Unlink \(link.studentDisplayName)?",
            isPresented: $showUnlinkAlert
        ) {
            Button("Unlink", role: .destructive) {
                Task { await performUnlink() }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("They'll lose access to goals and new tasks. History on both sides is preserved.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(link.studentDisplayName)
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .lineLimit(1)
            if let instrument = link.studentInstrument, !instrument.isEmpty {
                Text(instrument)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
            }
            if let lastSeen = link.lastSeenAt {
                Text("Last seen \(Self.relativeFormatter.localizedString(for: lastSeen, relativeTo: .now))")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink45)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Goals",
                ctaTitle: "Add goal",
                onTap: { showAddGoal = true }
            )

            if goals.isEmpty {
                sectionPlaceholder(
                    copy: "No goals yet - add one to pin tasks to.",
                    ctaTitle: "Add goal",
                    onCTA: { showAddGoal = true }
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(goals) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if goal.isDone {
                    Circle().fill(palette.accent)
                    PraccyIcon.view(for: .check, tint: palette.onAccent, size: 12)
                } else {
                    Circle().strokeBorder(palette.accent.opacity(0.5), lineWidth: 2)
                }
            }
            .frame(width: 24, height: 24)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .strikethrough(goal.isDone, color: PraccyColor.ink.opacity(0.5))
                    .multilineTextAlignment(.leading)
                if !goal.subtitle.isEmpty {
                    Text(goal.subtitle)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    PraccyIcon.view(for: .flag, tint: PraccyColor.ink45, size: 10)
                    Text(goal.dueLabel)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                }
            }

            Spacer(minLength: 8)

            Button {
                goalPendingRemoval = goal
            } label: {
                PraccyIcon.view(for: .minus, tint: PraccyColor.ink60, size: 12)
                    .padding(9)
                    .background(Circle().strokeBorder(PraccyColor.ink10, lineWidth: 1.5))
            }
            .buttonStyle(.praccyPress(offset: 2))
            .accessibilityLabel("Remove \(goal.title)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow.opacity(0.18), offset: 3)
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Assigned tasks",
                ctaTitle: "Assign task",
                onTap: { showAssignTask = true }
            )

            if tasks.isEmpty {
                sectionPlaceholder(
                    copy: "No tasks yet. Assign one to get \(link.studentDisplayName) started.",
                    ctaTitle: "Assign task",
                    onCTA: { showAssignTask = true }
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(openTasks) { task in
                        taskRow(task)
                    }
                    if !doneTasks.isEmpty {
                        Text("Done")
                            .font(PraccyFont.meta)
                            .tracking(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(PraccyColor.ink60)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        ForEach(doneTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: PracticeTask) -> some View {
        Button {
            taskSelection = TaskSelection(id: task.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if task.isDone {
                        Circle().fill(palette.accent)
                        PraccyIcon.view(for: .check, tint: palette.onAccent, size: 10)
                    } else {
                        Circle().strokeBorder(palette.accent.opacity(0.4), lineWidth: 2)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(task.isDone ? PraccyColor.ink60 : PraccyColor.ink)
                        .strikethrough(task.isDone, color: PraccyColor.ink.opacity(0.5))
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 10) {
                        if let goal = task.goal {
                            HStack(spacing: 4) {
                                PraccyIcon.view(for: .flag, tint: PraccyColor.ink45, size: 9)
                                Text(goal.title)
                                    .font(PraccyFont.meta)
                                    .foregroundStyle(PraccyColor.ink60)
                                    .lineLimit(1)
                            }
                        }
                        if let minutes = task.targetMinutes {
                            HStack(spacing: 4) {
                                PraccyIcon.view(for: .clock, tint: PraccyColor.ink45, size: 9)
                                Text("\(minutes) min")
                                    .font(PraccyFont.meta)
                                    .foregroundStyle(PraccyColor.ink60)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PraccyIcon.view(for: .chevronRight, tint: PraccyColor.ink45, size: 12)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PraccyRadius.card)
                    .strokeBorder(palette.accent.opacity(0.1), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPress(offset: 2))
    }

    // MARK: - Unlink

    private var unlinkButton: some View {
        Button(role: .destructive) {
            showUnlinkAlert = true
        } label: {
            Text("Unlink student")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
    }

    // MARK: - Section chrome

    private func sectionHeader(title: String, ctaTitle: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(PraccyColor.ink)
            Spacer()
            Button(action: onTap) {
                HStack(spacing: 5) {
                    PraccyIcon.view(for: .plus, tint: palette.accent, size: 11)
                    Text(ctaTitle)
                        .font(PraccyFont.meta)
                        .foregroundStyle(palette.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: PraccyRadius.chip))
            }
            .buttonStyle(.praccyPress(offset: 2))
        }
    }

    private func sectionPlaceholder(copy: String, ctaTitle: String, onCTA: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(copy)
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: PraccyRadius.card)
                .strokeBorder(PraccyColor.ink10, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }

    // MARK: - Actions

    private func removeGoal(_ goal: Goal) async {
        let remoteID = goal.remoteID
        goalPendingRemoval = nil
        modelContext.delete(goal)
        try? modelContext.save()
        if let remoteID {
            _ = try? await backend.removeGoal(remoteGoalID: remoteID)
        }
    }

    private func performUnlink() async {
        unlinkError = nil
        do {
            try await backend.unlink(remoteLinkID: link.remoteLinkID ?? link.remoteStudentID)
            // Nullify assignedTo on tasks/goals and mark the link severed; rows stay in history.
            for task in modelContext.assignedTasks(for: link) {
                task.assignedTo = nil
            }
            for goal in modelContext.goals(for: link) {
                goal.assignedTo = nil
            }
            link.state = .severed
            try? modelContext.save()
            dismiss()
        } catch {
            unlinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Formatters

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}

#if DEBUG
#Preview("Seeded student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    let link = container.mainContext.activeRoster().first!
    return NavigationStack {
        StudentDetailScreen(link: link, palette: .violet)
    }
    .modelContainer(container)
    .environment(\.backend, MockBackend(seed: .signedInTeacher))
}
#endif
