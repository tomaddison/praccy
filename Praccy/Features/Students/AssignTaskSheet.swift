import SwiftUI
import SwiftData

/// Teacher-side task composer. `editing != nil` updates in place; `assignTask` is the upsert path.
struct AssignTaskSheet: View {
    let link: StudentLink
    let palette: AccentPalette
    let editing: PracticeTask?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendQueue) private var backendQueue
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var teacherNote: String
    @State private var hasTarget: Bool
    @State private var targetMinutes: Int
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var selectedGoalID: UUID?
    @State private var isSaving: Bool = false

    @FocusState private var focusedField: Field?

    fileprivate enum Field: Hashable { case title, detail, note }

    init(link: StudentLink, palette: AccentPalette, editing: PracticeTask? = nil) {
        self.link = link
        self.palette = palette
        self.editing = editing

        _title = State(initialValue: editing?.title ?? "")
        _detail = State(initialValue: editing?.detail ?? "")
        _teacherNote = State(initialValue: editing?.teacherNote ?? "")
        _hasTarget = State(initialValue: editing?.targetMinutes != nil)
        _targetMinutes = State(initialValue: editing?.targetMinutes ?? 15)
        _hasDueDate = State(initialValue: editing?.dueDate != nil || editing == nil)
        _dueDate = State(initialValue: editing?.dueDate ?? Calendar.current.startOfDay(for: .now))
        _selectedGoalID = State(initialValue: editing?.goal?.id)
    }

    /// Open goals plus whichever goal the task being edited is currently linked to (even if done),
    /// so an existing link survives the round-trip through the picker.
    private var availableGoals: [Goal] {
        let all = modelContext.goals(for: link)
        return all.filter { !$0.isDone || $0.id == selectedGoalID }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            PraccySheetHeader(title: editing == nil ? "Assign task" : "Edit task", palette: palette) {
                guard !isSaving else { return }
                dismiss()
            }
            ScrollView {
                VStack(spacing: 28) {
                    taskCard
                    targetCard
                    dueDateCard
                    if !availableGoals.isEmpty {
                        goalCard
                    }
                    teacherNoteCard
                    primaryButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.bg.ignoresSafeArea())
    }

    // MARK: - Cards

    private var taskCard: some View {
        SettingsSectionCard(eyebrow: "For \(link.studentDisplayName)", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                PraccyTextField(
                    placeholder: "Title",
                    text: $title,
                    field: Field.title,
                    focus: $focusedField,
                    submitLabel: .done,
                    onSubmit: { focusedField = nil }
                )
                PraccyTextField(
                    placeholder: "What to practise (optional)",
                    text: $detail,
                    field: Field.detail,
                    focus: $focusedField,
                    submitLabel: .done,
                    onSubmit: { focusedField = nil }
                )
            }
        }
    }

    private var targetCard: some View {
        SettingsSectionCard(eyebrow: "Target minutes", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Target minutes", isOn: $hasTarget)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .tint(palette.accent)

                if hasTarget {
                    HStack {
                        Text("\(targetMinutes) min")
                            .font(PraccyFont.task)
                            .tracking(-0.2)
                            .foregroundStyle(PraccyColor.ink)
                        Spacer()
                        Stepper("", value: $targetMinutes, in: 1...120)
                            .labelsHidden()
                            .tint(palette.accent)
                    }
                }

                Text(hasTarget
                     ? "Powers the progress ring on their Home card."
                     : "Free-form tasks show a simple tick instead of a ring.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
            }
        }
    }

    private var dueDateCard: some View {
        SettingsSectionCard(eyebrow: "Due date", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Set a due date", isOn: $hasDueDate)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .tint(palette.accent)

                if hasDueDate {
                    DatePicker(
                        "Due",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .tint(palette.accent)
                }
            }
        }
    }

    private var goalCard: some View {
        SettingsSectionCard(eyebrow: "Ladders up to (optional)", palette: palette) {
            Menu {
                Picker("Goal", selection: $selectedGoalID) {
                    Text("No goal").tag(UUID?.none)
                    ForEach(availableGoals) { goal in
                        Text(goal.title).tag(UUID?.some(goal.id))
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(selectedGoalLabel)
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(selectedGoalID == nil ? PraccyColor.ink60 : PraccyColor.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PraccyIcon.view(for: .chevronRight, tint: palette.accent, size: 12)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                        .fill(PraccyColor.ink05)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var selectedGoalLabel: String {
        availableGoals.first { $0.id == selectedGoalID }?.title ?? "No goal"
    }

    private var teacherNoteCard: some View {
        SettingsSectionCard(eyebrow: "Teacher note (optional)", palette: palette) {
            PraccyTextField(
                placeholder: "Anything to call out?",
                text: $teacherNote,
                field: Field.note,
                focus: $focusedField,
                submitLabel: .done,
                onSubmit: { focusedField = nil }
            )
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await save() }
        } label: {
            Text(primaryButtonLabel)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    palette.accent.opacity(canSave ? 1 : 0.4),
                    in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                )
        }
        .buttonStyle(.praccyPress(shadow: canSave ? palette.shadow : .clear))
        .disabled(!canSave)
        .padding(.top, 4)
    }

    private var primaryButtonLabel: String {
        if isSaving { return editing == nil ? "Assigning…" : "Saving…" }
        return editing == nil ? "Assign" : "Save"
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = teacherNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        focusedField = nil
        isSaving = true

        let pickedGoal = availableGoals.first { $0.id == selectedGoalID }
        let resolvedDue = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
        let resolvedTarget = hasTarget ? targetMinutes : nil
        let resolvedNote: String? = trimmedNote.isEmpty ? nil : trimmedNote

        let remoteID: String
        if let existing = editing {
            existing.title = trimmedTitle
            existing.detail = trimmedDetail
            existing.targetMinutes = resolvedTarget
            existing.dueDate = resolvedDue
            existing.teacherNote = resolvedNote
            existing.goal = pickedGoal
            remoteID = existing.remoteID ?? UUID().uuidString
            existing.remoteID = remoteID
        } else {
            remoteID = UUID().uuidString
            let task = PracticeTask(
                title: trimmedTitle,
                detail: trimmedDetail,
                targetMinutes: resolvedTarget,
                dueDate: resolvedDue,
                teacherNote: resolvedNote,
                goal: pickedGoal,
                assignedTo: link,
                remoteID: remoteID
            )
            modelContext.insert(task)
        }
        try? modelContext.save()

        let payload = AssignedTaskPayload(
            remoteID: remoteID,
            remoteLinkID: link.remoteLinkID ?? link.remoteStudentID,
            title: trimmedTitle,
            detail: trimmedDetail,
            targetMinutes: resolvedTarget,
            dueDate: resolvedDue,
            goalRemoteID: pickedGoal?.remoteID,
            goalTitle: pickedGoal?.title,
            teacherNote: resolvedNote,
            isDone: editing?.isDone ?? false,
            completedAt: editing?.completedAt
        )
        if let queue = backendQueue {
            await queue.enqueue(.assignTask(payload: payload, toStudentRemoteID: link.remoteStudentID))
        }

        isSaving = false
        dismiss()
    }
}

#if DEBUG
#Preview("Assign task") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    let link = container.mainContext.activeRoster().first!
    return AssignTaskSheet(link: link, palette: .violet)
        .modelContainer(container)
        .environment(\.backend, MockBackend(seed: .signedInTeacher))
}
#endif
