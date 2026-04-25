import Foundation
import SwiftData

/// A single practice item, always teacher-assigned. Named `PracticeTask` to avoid
/// collision with Swift concurrency's `Task`. Per-day only; no recurrence.
@Model
final class PracticeTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var targetMinutes: Int?
    var isDone: Bool
    var completedAt: Date?
    var createdAt: Date
    var dueDate: Date?
    var teacherNote: String?

    /// CloudKit record name. `nil` for local-only tasks and seeds; populated on reconcile.
    var remoteID: String?

    /// Nullify on goal delete so retiring a goal doesn't wipe practice history.
    var goal: Goal?

    @Relationship(deleteRule: .cascade, inverse: \Recording.task)
    var recordings: [Recording] = []

    /// Set on the student's device; mirror of `assignedTo`.
    var assignedBy: TeacherLink?

    /// Set on the teacher's device; mirror of `assignedBy`. Reconcile fills the opposite side.
    var assignedTo: StudentLink?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        targetMinutes: Int? = nil,
        isDone: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        dueDate: Date? = nil,
        teacherNote: String? = nil,
        goal: Goal? = nil,
        assignedBy: TeacherLink? = nil,
        assignedTo: StudentLink? = nil,
        remoteID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.targetMinutes = targetMinutes
        self.isDone = isDone
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.teacherNote = teacherNote
        self.goal = goal
        self.assignedBy = assignedBy
        self.assignedTo = assignedTo
        self.remoteID = remoteID
    }

    var hasAudio: Bool { !recordings.isEmpty }
}
