import Foundation
import SwiftData

/// A student's view of a linked teacher.
@Model
final class TeacherLink {
    @Attribute(.unique) var id: UUID
    var teacherDisplayName: String
    var teacherInstrument: String?

    /// CloudKit recordID.recordName for the teacher user.
    var remoteTeacherID: String

    /// Accepted share's root `StudentLinkRecord` name. Authoritative for severing. Optional for older rows.
    var remoteLinkID: String?

    var linkedAt: Date
    var state: LinkState

    /// Nullify on delete; without this, `task.assignedBy` holds a dangling ID and crashes on read.
    @Relationship(deleteRule: .nullify, inverse: \PracticeTask.assignedBy)
    var assignedTasks: [PracticeTask] = []

    @Relationship(deleteRule: .nullify, inverse: \Goal.assignedBy)
    var assignedGoals: [Goal] = []

    init(
        id: UUID = UUID(),
        teacherDisplayName: String,
        teacherInstrument: String? = nil,
        remoteTeacherID: String,
        remoteLinkID: String? = nil,
        linkedAt: Date = .now,
        state: LinkState = .active
    ) {
        self.id = id
        self.teacherDisplayName = teacherDisplayName
        self.teacherInstrument = teacherInstrument
        self.remoteTeacherID = remoteTeacherID
        self.remoteLinkID = remoteLinkID
        self.linkedAt = linkedAt
        self.state = state
    }
}
