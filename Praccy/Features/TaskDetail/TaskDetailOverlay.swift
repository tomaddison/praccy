import SwiftUI
import SwiftData
import UIKit

/// Full-screen slide-up practice screen for a single task. Presentation is owned by `RootView`;
/// this view resolves the task and drives recording/playback locally.
struct TaskDetailOverlay: View {
    let taskID: UUID
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Query private var matchingTasks: [PracticeTask]

    init(taskID: UUID, palette: AccentPalette) {
        self.taskID = taskID
        self.palette = palette
        self._matchingTasks = Query(
            filter: #Predicate<PracticeTask> { $0.id == taskID }
        )
    }

    private var task: PracticeTask? { matchingTasks.first }

    var body: some View {
        ZStack(alignment: .top) {
            palette.bg.ignoresSafeArea()

            if let task {
                content(for: task)
            } else {
                missingState
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for task: PracticeTask) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let goal = task.goal {
                            GoalChip(title: goal.title, palette: palette)
                                .padding(.bottom, 12)
                        }

                        Text(task.title)
                            .font(PraccyFont.title)
                            .tracking(-0.5)
                            .foregroundStyle(PraccyColor.ink)
                            .lineLimit(4)

                        if !task.detail.isEmpty {
                            Text(task.detail)
                                .font(PraccyFont.task)
                                .foregroundStyle(PraccyColor.ink60)
                                .padding(.top, 12)
                        }

                        if let note = task.teacherNote, !note.isEmpty {
                            TeacherNoteCard(
                                teacherName: task.assignedBy?.teacherDisplayName,
                                note: note,
                                palette: palette
                            )
                            .padding(.top, 18)
                        }

                        StatsRow(task: task, palette: palette)
                            .padding(.top, 18)

                        RecordingCard(
                            task: task,
                            palette: palette,
                            modelContext: modelContext
                        )
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                }
                .padding(.bottom, 170)
            }

            StickyMarkDone(task: task, palette: palette, modelContext: modelContext)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    /// Race guard for a task deleted mid-view.
    @ViewBuilder
    private var missingState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Task not found.")
                .font(PraccyFont.task)
                .foregroundStyle(PraccyColor.ink60)
            Spacer()
        }
    }
}

// MARK: - Goal chip

private struct GoalChip: View {
    let title: String
    let palette: AccentPalette

    var body: some View {
        HStack(spacing: 6) {
            PraccyIcon.view(for: .flag, tint: .white, size: 12)
            Text(title)
                .font(PraccyFont.meta)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.accent, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal: \(title)")
    }
}

// MARK: - Stats row

private struct StatsRow: View {
    let task: PracticeTask
    let palette: AccentPalette

    var body: some View {
        HStack(spacing: 10) {
            StatCard(
                palette: palette,
                label: "Target",
                value: task.targetMinutes.map { "\($0) min" } ?? "-"
            )
            StatCard(
                palette: palette,
                label: "Due",
                value: Self.dueLabel(task.dueDate)
            )
        }
    }

    private static func dueLabel(_ date: Date?) -> String {
        guard let date else { return "-" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tmrw" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

private struct StatCard: View {
    let palette: AccentPalette
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .praccyEyebrow()
                .foregroundStyle(Color.white.opacity(0.85))
            Text(value)
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.card - 6))
        .praccySolidShadow(color: palette.shadow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

// MARK: - Sticky CTA

/// Bottom-pinned "Mark as done" that fires confetti and flips to ✓ Done.
/// Teacher-assigned tasks also enqueue `markTaskComplete` + an upload per pending recording.
private struct StickyMarkDone: View {
    let task: PracticeTask
    let palette: AccentPalette
    let modelContext: ModelContext

    @Environment(\.backendQueue) private var queue

    @State private var burst: UUID? = nil

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                if task.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(PraccyFont.task)
                }
                Text(task.isDone ? "Done" : "Mark as done")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
            }
            .foregroundStyle(task.isDone ? .white : PraccyColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(task.isDone ? PraccyColor.success : Color.white)
            )
        }
        .buttonStyle(.praccyPress(shadow: task.isDone ? PraccyColor.success.opacity(0.5) : PraccyColor.ink.opacity(0.15)))
        .overlay(alignment: .center) {
            if burst != nil {
                // Pin via overlay; `ConfettiBurst` hosts a greedy GeometryReader.
                ConfettiBurst(accent: .white) { burst = nil }
                    .frame(width: 220, height: 80)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(task.isDone ? "Marked done. Tap to undo." : "Mark as done")
    }

    private func handleTap() {
        let willComplete = !task.isDone
        task.isDone.toggle()
        task.completedAt = task.isDone ? .now : nil
        try? modelContext.save()
        if willComplete {
            burst = UUID()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            enqueueRemoteCompletion()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    /// Only tasks with a `remoteID` (teacher-assigned) sync back; local-only recordings stay on-device.
    private func enqueueRemoteCompletion() {
        guard let queue, let remoteID = task.remoteID else { return }
        let completedAt = task.completedAt ?? .now
        let pendingUploads: [(UUID, String)] = task.recordings
            .filter { $0.uploadedAt == nil }
            .map { ($0.id, $0.fileURL.path) }

        Task {
            await queue.enqueue(.markTaskComplete(
                remoteTaskID: remoteID,
                completedAt: completedAt
            ))
            for (recordingID, path) in pendingUploads {
                await queue.enqueue(.uploadRecording(
                    fileURLPath: path,
                    remoteTaskID: remoteID,
                    localRecordingID: recordingID
                ))
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Task detail - teacher-assigned with recording") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)

    let ctx = container.mainContext
    let descriptor = FetchDescriptor<PracticeTask>(
        predicate: #Predicate { $0.title.contains("Record one full play") }
    )
    let id = (try? ctx.fetch(descriptor))?.first?.id ?? UUID()

    return TaskDetailOverlay(taskID: id, palette: .violet)
        .modelContainer(container)
}

#Preview("Task detail - no audio") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.role = .student

    let today = Calendar.current.startOfDay(for: .now)
    let task = PracticeTask(
        title: "Warm up with C major scales",
        detail: "Two octaves, slow. Eyes closed on the way back.",
        targetMinutes: 8,
        dueDate: today
    )
    container.mainContext.insert(task)

    return TaskDetailOverlay(taskID: task.id, palette: .violet)
        .modelContainer(container)
}

#Preview("Task detail - done") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.role = .student

    let today = Calendar.current.startOfDay(for: .now)
    let task = PracticeTask(
        title: "Clap the rhythm of piece B",
        detail: "Count out loud: 1 & 2 & 3 & 4 &.",
        targetMinutes: 3,
        isDone: true,
        completedAt: .now,
        dueDate: today
    )
    container.mainContext.insert(task)

    return TaskDetailOverlay(taskID: task.id, palette: .violet)
        .modelContainer(container)
}
#endif
