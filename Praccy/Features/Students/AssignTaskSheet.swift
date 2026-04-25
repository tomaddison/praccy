import SwiftUI
import SwiftData

/// Teacher-side task composer. Inserts locally for immediate feedback, then enqueues `assignTask`.
struct AssignTaskSheet: View {
    let link: StudentLink
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendQueue) private var backendQueue
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var teacherNote: String = ""
    @State private var hasTarget: Bool = false
    @State private var targetMinutes: Int = 15
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedGoalID: UUID? = nil
    @State private var isSaving: Bool = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, detail, note }

    private var availableGoals: [Goal] {
        modelContext.goals(for: link).filter { !$0.isDone }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            PraccySheetHeader(title: "Assign task", palette: palette) {
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
                textField(
                    placeholder: "Title",
                    text: $title,
                    field: .title,
                    lineLimit: 1...3,
                    submitLabel: .next,
                    onSubmit: { focusedField = .detail }
                )
                textField(
                    placeholder: "What to practise (optional)",
                    text: $detail,
                    field: .detail,
                    lineLimit: 1...4,
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
        SettingsSectionCard(eyebrow: "Goal (optional)", palette: palette) {
            HStack {
                Text("Ladders up to")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                Spacer()
                Picker("Ladders up to", selection: $selectedGoalID) {
                    Text("None").tag(UUID?.none)
                    ForEach(availableGoals) { goal in
                        Text(goal.title).tag(UUID?.some(goal.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(palette.accent)
            }
        }
    }

    private var teacherNoteCard: some View {
        SettingsSectionCard(eyebrow: "Teacher note (optional)", palette: palette) {
            textField(
                placeholder: "Anything to call out?",
                text: $teacherNote,
                field: .note,
                lineLimit: 1...4,
                submitLabel: .done,
                onSubmit: { focusedField = nil }
            )
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await save() }
        } label: {
            Text(isSaving ? "Assigning…" : "Assign")
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

    // MARK: - Field

    @ViewBuilder
    private func textField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        lineLimit: ClosedRange<Int>,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder).foregroundStyle(PraccyColor.ink45),
            axis: .vertical
        )
            .lineLimit(lineLimit)
            .font(PraccyFont.task)
            .tracking(-0.2)
            .foregroundStyle(PraccyColor.ink)
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                    .fill(PraccyColor.ink05)
            )
    }

    // MARK: - Save

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = teacherNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        focusedField = nil
        isSaving = true

        let pickedGoal = availableGoals.first { $0.id == selectedGoalID }
        let remoteID = UUID().uuidString
        let resolvedDue = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
        let resolvedTarget = hasTarget ? targetMinutes : nil
        let resolvedNote: String? = trimmedNote.isEmpty ? nil : trimmedNote

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
            isDone: false,
            completedAt: nil
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
