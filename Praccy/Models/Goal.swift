import Foundation
import SwiftData

/// Teacher-authored per-student aspiration. Binary done/not; no percent-complete.
@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String

    /// `nil` = ongoing (no target date).
    var dueDate: Date?

    var isDone: Bool
    var completedAt: Date?
    var createdAt: Date

    /// Backend record identifier. `nil` for seeds or goals that haven't reconciled yet.
    var remoteID: String?

    /// Set on the student's device; mirror of `assignedTo`.
    var assignedBy: TeacherLink?

    /// Set on the teacher's device; mirror of `assignedBy`.
    var assignedTo: StudentLink?

    /// Nullify on delete so removing a goal keeps practice history intact.
    @Relationship(deleteRule: .nullify, inverse: \PracticeTask.goal)
    var tasks: [PracticeTask] = []

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        remoteID: String? = nil,
        assignedBy: TeacherLink? = nil,
        assignedTo: StudentLink? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.dueDate = dueDate
        self.isDone = isDone
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.remoteID = remoteID
        self.assignedBy = assignedBy
        self.assignedTo = assignedTo
    }

    var dueLabel: String {
        guard let dueDate else { return "Ongoing" }
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df.string(from: dueDate)
    }
}
