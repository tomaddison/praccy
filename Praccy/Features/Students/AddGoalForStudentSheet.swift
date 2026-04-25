import SwiftUI
import SwiftData

/// Teacher-side goal composer. Pins the goal to `link` via `assignedTo` and
/// enqueues the write through `BackendOperationQueue`.
struct AddGoalForStudentSheet: View {
    let link: StudentLink
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendQueue) private var backendQueue
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Self.defaultDueDate
    @State private var isSaving: Bool = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, subtitle }

    private static var defaultDueDate: Date {
        Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            PraccySheetHeader(title: "New goal", palette: palette) {
                guard !isSaving else { return }
                dismiss()
            }
            ScrollView {
                VStack(spacing: 28) {
                    goalCard
                    targetDateCard
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

    private var goalCard: some View {
        SettingsSectionCard(eyebrow: "Goal for \(link.studentDisplayName)", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                textField(
                    placeholder: "Title",
                    text: $title,
                    field: .title,
                    axis: .vertical,
                    lineLimit: 1...3,
                    submitLabel: .next,
                    onSubmit: { focusedField = .subtitle }
                )
                textField(
                    placeholder: "Why it matters (optional)",
                    text: $subtitle,
                    field: .subtitle,
                    axis: .vertical,
                    lineLimit: 1...3,
                    submitLabel: .done,
                    onSubmit: { focusedField = nil }
                )
            }
        }
    }

    private var targetDateCard: some View {
        SettingsSectionCard(eyebrow: "Target date", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Set a target date", isOn: $hasDueDate)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .tint(palette.accent)

                if hasDueDate {
                    DatePicker(
                        "Target",
                        selection: $dueDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .tint(palette.accent)
                }

                Text(hasDueDate
                     ? "You can clear this later if the timeline shifts."
                     : "Ongoing goals never expire.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await save() }
        } label: {
            Text(isSaving ? "Saving…" : "Save")
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
        axis: Axis,
        lineLimit: ClosedRange<Int>,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: text, axis: axis)
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
                    .fill(palette.surface.opacity(0.5))
            )
            .overlay {
                RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                    .strokeBorder(palette.accent.opacity(0.18), lineWidth: 1.5)
            }
    }

    // MARK: - Save

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        focusedField = nil
        isSaving = true

        let remoteID = UUID().uuidString
        let resolvedDueDate = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil

        let goal = Goal(
            title: trimmedTitle,
            subtitle: trimmedSubtitle,
            dueDate: resolvedDueDate,
            remoteID: remoteID,
            assignedTo: link
        )
        modelContext.insert(goal)
        try? modelContext.save()

        let payload = AssignedGoalPayload(
            remoteID: remoteID,
            remoteLinkID: link.remoteLinkID ?? link.remoteStudentID,
            title: trimmedTitle,
            subtitle: trimmedSubtitle,
            dueDate: resolvedDueDate,
            isDone: false,
            completedAt: nil
        )
        if let queue = backendQueue {
            await queue.enqueue(.assignGoal(payload: payload, toStudentRemoteID: link.remoteStudentID))
        }

        isSaving = false
        dismiss()
    }
}

#if DEBUG
#Preview("Add goal for student") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    let link = container.mainContext.activeRoster().first!
    return AddGoalForStudentSheet(link: link, palette: .violet)
        .modelContainer(container)
        .environment(\.backend, MockBackend(seed: .signedInTeacher))
}
#endif
