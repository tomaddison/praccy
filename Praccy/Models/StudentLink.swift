import Foundation
import SwiftData

/// A teacher's view of a linked student. Mirror of `TeacherLink`.
@Model
final class StudentLink {
    @Attribute(.unique) var id: UUID
    var studentDisplayName: String
    var studentInstrument: String?

    /// CloudKit recordID.recordName for the student user.
    var remoteStudentID: String

    /// StudentLinkRecord recordName in the teacher's `PraccyRoster` zone.
    /// Authoritative for assign/unlink. Optional for older rows; fall back to `remoteStudentID`.
    var remoteLinkID: String?

    var linkedAt: Date
    var state: LinkState

    var lastSeenAt: Date?

    /// Nullify on delete; without this, `task.assignedTo` holds a dangling ID and crashes on read.
    @Relationship(deleteRule: .nullify, inverse: \PracticeTask.assignedTo)
    var assignedTasks: [PracticeTask] = []

    @Relationship(deleteRule: .nullify, inverse: \Goal.assignedTo)
    var assignedGoals: [Goal] = []

    init(
        id: UUID = UUID(),
        studentDisplayName: String,
        studentInstrument: String? = nil,
        remoteStudentID: String,
        remoteLinkID: String? = nil,
        linkedAt: Date = .now,
        state: LinkState = .active,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.studentDisplayName = studentDisplayName
        self.studentInstrument = studentInstrument
        self.remoteStudentID = remoteStudentID
        self.remoteLinkID = remoteLinkID
        self.linkedAt = linkedAt
        self.state = state
        self.lastSeenAt = lastSeenAt
    }
}
