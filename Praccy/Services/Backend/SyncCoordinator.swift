import Foundation
import SwiftData

/// Applies a `ReconcileChangeSet` into SwiftData. The only seam that knows both the backend's
/// DTOs and the `@Model` types. Order matters: links → goals → tasks → removals last.
@MainActor
struct SyncCoordinator {
    let modelContext: ModelContext

    func apply(_ changeSet: ReconcileChangeSet) {
        applyTeacherLinkUpserts(changeSet.upsertedTeacherLinks)
        applyStudentLinkUpserts(changeSet.upsertedStudentLinks)
        applyGoalUpserts(changeSet.upsertedGoals)
        applyTaskUpserts(changeSet.upsertedTasks)

        applyTaskRemovals(changeSet.removedTaskRemoteIDs)
        applyGoalRemovals(changeSet.removedGoalRemoteIDs)
        applyTeacherLinkSevers(changeSet.severedTeacherLinkRemoteIDs)
        applyStudentLinkSevers(changeSet.severedStudentLinkRemoteIDs)

        try? modelContext.save()
    }

    // MARK: - Links

    private func applyTeacherLinkUpserts(_ descriptors: [TeacherLinkDescriptor]) {
        for descriptor in descriptors {
            if let existing = findTeacherLink(remoteLinkID: descriptor.remoteLinkID) {
                existing.teacherDisplayName = descriptor.teacherDisplayName
                if let instrument = descriptor.teacherInstrument {
                    existing.teacherInstrument = instrument
                }
                existing.remoteTeacherID = descriptor.remoteTeacherID
                existing.state = .active
            } else {
                let link = TeacherLink(
                    teacherDisplayName: descriptor.teacherDisplayName,
                    teacherInstrument: descriptor.teacherInstrument,
                    remoteTeacherID: descriptor.remoteTeacherID,
                    remoteLinkID: descriptor.remoteLinkID,
                    linkedAt: descriptor.linkedAt,
                    state: .active
                )
                modelContext.insert(link)
            }
        }
    }

    private func applyStudentLinkUpserts(_ descriptors: [StudentLinkDescriptor]) {
        for descriptor in descriptors {
            if let existing = findStudentLink(remoteLinkID: descriptor.remoteLinkID) {
                existing.studentDisplayName = descriptor.studentDisplayName
                if let instrument = descriptor.studentInstrument {
                    existing.studentInstrument = instrument
                }
                if !descriptor.remoteStudentID.isEmpty {
                    existing.remoteStudentID = descriptor.remoteStudentID
                }
                existing.state = .active
                existing.lastSeenAt = .now
            } else {
                let link = StudentLink(
                    studentDisplayName: descriptor.studentDisplayName,
                    studentInstrument: descriptor.studentInstrument,
                    remoteStudentID: descriptor.remoteStudentID,
                    remoteLinkID: descriptor.remoteLinkID,
                    linkedAt: descriptor.linkedAt,
                    state: .active
                )
                modelContext.insert(link)
            }
        }
    }

    private func applyTeacherLinkSevers(_ remoteIDs: [String]) {
        for remoteID in remoteIDs {
            guard let link = findTeacherLink(remoteLinkID: remoteID) else { continue }
            link.state = .severed
        }
    }

    private func applyStudentLinkSevers(_ remoteIDs: [String]) {
        for remoteID in remoteIDs {
            guard let link = findStudentLink(remoteLinkID: remoteID) else { continue }
            link.state = .severed
        }
    }

    // MARK: - Goals

    private func applyGoalUpserts(_ payloads: [AssignedGoalPayload]) {
        for payload in payloads {
            let goal = findGoal(remoteID: payload.remoteID) ?? makeGoal(remoteID: payload.remoteID)
            goal.title = payload.title
            goal.subtitle = payload.subtitle
            goal.dueDate = payload.dueDate
            goal.isDone = payload.isDone
            goal.completedAt = payload.completedAt
            goal.assignedBy = findTeacherLink(remoteLinkID: payload.remoteLinkID)
            goal.assignedTo = findStudentLink(remoteLinkID: payload.remoteLinkID)
        }
    }

    private func applyGoalRemovals(_ remoteIDs: [String]) {
        for remoteID in remoteIDs {
            guard let goal = findGoal(remoteID: remoteID) else { continue }
            modelContext.delete(goal)
        }
    }

    private func makeGoal(remoteID: String) -> Goal {
        let goal = Goal(title: "", remoteID: remoteID)
        modelContext.insert(goal)
        return goal
    }

    // MARK: - Tasks

    private func applyTaskUpserts(_ payloads: [AssignedTaskPayload]) {
        for payload in payloads {
            let task = findTask(remoteID: payload.remoteID) ?? makeTask(remoteID: payload.remoteID)
            task.title = payload.title
            task.detail = payload.detail
            task.targetMinutes = payload.targetMinutes
            task.dueDate = payload.dueDate
            task.teacherNote = payload.teacherNote
            task.isDone = payload.isDone
            task.completedAt = payload.completedAt
            task.assignedBy = findTeacherLink(remoteLinkID: payload.remoteLinkID)
            task.assignedTo = findStudentLink(remoteLinkID: payload.remoteLinkID)
            if let goalRemoteID = payload.goalRemoteID {
                task.goal = findGoal(remoteID: goalRemoteID)
            } else {
                task.goal = nil
            }
        }
    }

    private func applyTaskRemovals(_ remoteIDs: [String]) {
        for remoteID in remoteIDs {
            guard let task = findTask(remoteID: remoteID) else { continue }
            modelContext.delete(task)
        }
    }

    private func makeTask(remoteID: String) -> PracticeTask {
        let task = PracticeTask(title: "", remoteID: remoteID)
        modelContext.insert(task)
        return task
    }

    // MARK: - Lookups

    private func findTeacherLink(remoteLinkID: String) -> TeacherLink? {
        let predicate = #Predicate<TeacherLink> { link in
            link.remoteLinkID != nil && link.remoteLinkID == remoteLinkID
        }
        return (try? modelContext.fetch(FetchDescriptor<TeacherLink>(predicate: predicate)))?.first
    }

    private func findStudentLink(remoteLinkID: String) -> StudentLink? {
        let predicate = #Predicate<StudentLink> { link in
            link.remoteLinkID != nil && link.remoteLinkID == remoteLinkID
        }
        return (try? modelContext.fetch(FetchDescriptor<StudentLink>(predicate: predicate)))?.first
    }

    private func findGoal(remoteID: String) -> Goal? {
        let predicate = #Predicate<Goal> { goal in
            goal.remoteID != nil && goal.remoteID == remoteID
        }
        return (try? modelContext.fetch(FetchDescriptor<Goal>(predicate: predicate)))?.first
    }

    private func findTask(remoteID: String) -> PracticeTask? {
        let predicate = #Predicate<PracticeTask> { task in
            task.remoteID != nil && task.remoteID == remoteID
        }
        return (try? modelContext.fetch(FetchDescriptor<PracticeTask>(predicate: predicate)))?.first
    }
}
