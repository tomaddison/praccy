#if DEBUG
import Foundation
import SwiftData
import SwiftUI

// Preview + simulator seed data. DEBUG-only; never shipped.

@MainActor
enum SeedData {
    // MARK: Student seed

    /// Student account with one teacher, two goals, today's six tasks, and a completion history.
    static func seedStudent(in context: ModelContext) {
        let settings = UserSettings.current(in: context)
        settings.role = .student
        settings.displayName = "Luca"
        settings.instrument = "Piano"
        settings.onboardingCompleted = true

        // Keychain fixture so Account section reads as signed in and Sign out is enabled.
        KeychainStore.save(AppleSignInService.Summary.devFixture.userIdentifier)

        let teacher = TeacherLink(
            teacherDisplayName: "Claire",
            teacherInstrument: "Piano",
            remoteTeacherID: "seed-teacher-claire",
            remoteLinkID: "seed-link-claire",
            state: .active
        )
        context.insert(teacher)

        let grade1 = Goal(
            title: "Pass Grade 1 ABRSM",
            subtitle: "Prepare all pieces, scales, and aural tests.",
            dueDate: Self.date(year: 2026, month: 8, day: 16),
            assignedBy: teacher
        )
        context.insert(grade1)

        let bassClef = Goal(
            title: "Learn to read bass clef",
            subtitle: "All the lines and spaces, no cheating.",
            assignedBy: teacher
        )
        context.insert(bassClef)

        let today = Calendar.current.startOfDay(for: .now)
        let week: [(title: String, detail: String, minutes: Int, done: Bool, audio: Bool)] = [
            (
                "C major scale - hands together",
                "4 times through, slow and even.",
                5, true, false
            ),
            (
                "Minuet in G - bars 1–8",
                "Right hand only. Mind the fingering on bar 5.",
                10, true, false
            ),
            (
                "Clap the rhythm of piece B",
                "Count out loud: 1 & 2 & 3 & 4 &.",
                3, false, false
            ),
            (
                "Sight-reading card #14",
                "Don't stop - keep going if you slip.",
                4, false, false
            ),
            (
                "Record one full play of Minuet in G",
                "Listen back and note anything to fix tomorrow.",
                6, false, true
            ),
            (
                "Listen to the aural test track",
                "Spot the higher note - there are 5 on the track.",
                4, false, false
            ),
        ]

        for entry in week {
            let task = PracticeTask(
                title: entry.title,
                detail: entry.detail,
                targetMinutes: entry.minutes,
                isDone: entry.done,
                completedAt: entry.done ? today.addingTimeInterval(9 * 3600) : nil,
                dueDate: today,
                teacherNote: entry.audio
                    ? "Post this one when you're happy with it - I'll listen back."
                    : nil,
                goal: grade1,
                assignedBy: teacher
            )
            context.insert(task)

            if entry.audio {
                // Placeholder row so `hasAudio` flips on without an actual file.
                let recording = Recording(
                    fileURL: URL(fileURLWithPath: "/dev/null"),
                    duration: 42,
                    task: task
                )
                context.insert(recording)
            }
        }

        let completedDays = [6, 7, 9, 13, 14, 15]
        for day in completedDays {
            guard let date = Self.date(year: 2026, month: 4, day: day) else { continue }
            let task = PracticeTask(
                title: "Daily practice - \(day) Apr",
                detail: "",
                targetMinutes: 12,
                isDone: true,
                completedAt: date.addingTimeInterval(10 * 3600),
                createdAt: date,
                dueDate: date,
                goal: grade1,
                assignedBy: teacher
            )
            context.insert(task)
        }
    }

    // MARK: Teacher seed

    /// Teacher account with a three-student roster (active, active, pending) and per-student goals + tasks.
    static func seedTeacher(in context: ModelContext) {
        let settings = UserSettings.current(in: context)
        settings.role = .teacher
        settings.displayName = "Claire"
        settings.onboardingCompleted = true

        let today = Calendar.current.startOfDay(for: .now)

        let luca = StudentLink(
            studentDisplayName: "Luca",
            studentInstrument: "Piano",
            remoteStudentID: "seed-student-0",
            remoteLinkID: "seed-link-luca",
            state: .active,
            lastSeenAt: .now.addingTimeInterval(-3600)
        )
        let ada = StudentLink(
            studentDisplayName: "Ada",
            studentInstrument: "Violin",
            remoteStudentID: "seed-student-1",
            remoteLinkID: "seed-link-ada",
            state: .active,
            lastSeenAt: .now.addingTimeInterval(-86400 * 2)
        )
        let theo = StudentLink(
            studentDisplayName: "Theo",
            studentInstrument: "Guitar",
            remoteStudentID: "seed-student-2",
            remoteLinkID: "seed-link-theo",
            state: .pending,
            lastSeenAt: nil
        )
        context.insert(luca)
        context.insert(ada)
        context.insert(theo)

        let lucaGrade1 = Goal(
            title: "Pass Grade 1 ABRSM",
            subtitle: "Prepare all pieces, scales, and aural tests.",
            dueDate: Self.date(year: 2026, month: 8, day: 16),
            assignedTo: luca
        )
        let lucaBass = Goal(
            title: "Learn to read bass clef",
            subtitle: "All the lines and spaces, no cheating.",
            assignedTo: luca
        )
        context.insert(lucaGrade1)
        context.insert(lucaBass)

        let lucaTasks: [(title: String, detail: String, minutes: Int, done: Bool, goal: Goal)] = [
            ("C major scale - hands together", "4 times through, slow and even.", 5, false, lucaGrade1),
            ("Minuet in G - bars 1–8", "Right hand only. Mind bar 5 fingering.", 10, false, lucaGrade1),
            ("Sight-reading card #14", "Don't stop - keep going if you slip.", 4, true, lucaBass),
        ]
        for entry in lucaTasks {
            let task = PracticeTask(
                title: entry.title,
                detail: entry.detail,
                targetMinutes: entry.minutes,
                isDone: entry.done,
                completedAt: entry.done ? today.addingTimeInterval(9 * 3600) : nil,
                dueDate: today,
                goal: entry.goal,
                assignedTo: luca
            )
            context.insert(task)
        }

        let adaGoal = Goal(
            title: "First position cleanly",
            subtitle: "Solid intonation on D and A strings.",
            assignedTo: ada
        )
        context.insert(adaGoal)
        let adaTask = PracticeTask(
            title: "Long tones - D string",
            detail: "Whole bow, 8 seconds each. Listen for the core of the note.",
            targetMinutes: 6,
            isDone: false,
            dueDate: today,
            goal: adaGoal,
            assignedTo: ada
        )
        context.insert(adaTask)
    }

    // MARK: - Helpers

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)
    }
}

// MARK: - Preview smoke tests

#Preview("Student seed") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return SeedSmokeList<PracticeTask>(
        title: "Today",
        rowLabel: { "\($0.title) · \($0.targetMinutes ?? 0)m \($0.isDone ? "✓" : "")" }
    )
    .modelContainer(container)
}

#Preview("Teacher seed") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    return SeedSmokeList<StudentLink>(
        title: "Roster",
        rowLabel: { "\($0.studentDisplayName) · \($0.state.rawValue)" }
    )
    .modelContainer(container)
}

private struct SeedSmokeList<T: PersistentModel>: View {
    let title: String
    let rowLabel: (T) -> String
    @Query private var rows: [T]

    var body: some View {
        NavigationStack {
            List(rows, id: \.persistentModelID) { row in
                Text(rowLabel(row))
            }
            .navigationTitle(title)
        }
    }
}
#endif
