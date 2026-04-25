import Foundation
import SwiftData

// MARK: - ModelContext query helpers
//
// `#Predicate` bodies must be a single expression: AND conditions together and
// force-unwrap optionals only after an explicit `!= nil` guard.

extension ModelContext {
    /// Tasks on `day`, undone first then `createdAt` ascending.
    func tasks(on day: Date = .now) -> [PracticeTask] {
        let start = Self.praccyCalendar.startOfDay(for: day)
        let end = Self.praccyCalendar.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = #Predicate<PracticeTask> { task in
            task.dueDate != nil && task.dueDate! >= start && task.dueDate! < end
        }
        var descriptor = FetchDescriptor<PracticeTask>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\PracticeTask.createdAt, order: .forward)]
        let all = (try? fetch(descriptor)) ?? []
        return all.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone && b.isDone }
            return a.createdAt < b.createdAt
        }
    }

    func todaysTasks() -> [PracticeTask] { tasks(on: .now) }

    /// Start-of-day timestamps in `range` that have at least one due task.
    func dueDayStarts(in range: DateInterval) -> Set<Date> {
        let start = range.start
        let end = range.end
        let predicate = #Predicate<PracticeTask> { task in
            task.dueDate != nil
                && task.dueDate! >= start
                && task.dueDate! < end
        }
        let tasks = (try? fetch(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? []
        let cal = Self.praccyCalendar
        return Set(tasks.compactMap { task in
            task.dueDate.map { cal.startOfDay(for: $0) }
        })
    }

    /// Start-of-day timestamps in `range` with at least one completed task.
    func completedDayStarts(in range: DateInterval) -> Set<Date> {
        let start = range.start
        let end = range.end
        let predicate = #Predicate<PracticeTask> { task in
            task.isDone
                && task.completedAt != nil
                && task.completedAt! >= start
                && task.completedAt! < end
        }
        let tasks = (try? fetch(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? []
        let cal = Self.praccyCalendar
        return Set(tasks.compactMap { task in
            task.completedAt.map { cal.startOfDay(for: $0) }
        })
    }

    /// Day numbers (1…31) in `reference`'s month with at least one completion.
    func completedDays(inMonth reference: Date) -> Set<Int> {
        let comps = Self.praccyCalendar.dateComponents([.year, .month], from: reference)
        let start = Self.praccyCalendar.date(from: comps) ?? reference
        let end = Self.praccyCalendar.date(byAdding: .month, value: 1, to: start) ?? start
        let predicate = #Predicate<PracticeTask> { task in
            task.isDone
                && task.completedAt != nil
                && task.completedAt! >= start
                && task.completedAt! < end
        }
        let tasks = (try? fetch(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? []
        let cal = Self.praccyCalendar
        return Set(tasks.compactMap { task in
            task.completedAt.map { cal.component(.day, from: $0) }
        })
    }

    func activeGoals() -> [Goal] {
        let predicate = #Predicate<Goal> { !$0.isDone }
        var descriptor = FetchDescriptor<Goal>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\Goal.createdAt, order: .reverse)]
        return (try? fetch(descriptor)) ?? []
    }

    func activeTeacherLinks() -> [TeacherLink] {
        let activeRaw = LinkState.active.rawValue
        let predicate = #Predicate<TeacherLink> { $0.state.rawValue == activeRaw }
        var descriptor = FetchDescriptor<TeacherLink>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\TeacherLink.linkedAt, order: .reverse)]
        return (try? fetch(descriptor)) ?? []
    }

    /// Teacher roster, active before pending. Severed excluded.
    func activeRoster() -> [StudentLink] {
        let severedRaw = LinkState.severed.rawValue
        let predicate = #Predicate<StudentLink> { $0.state.rawValue != severedRaw }
        let links = (try? fetch(FetchDescriptor<StudentLink>(predicate: predicate))) ?? []
        return links.sorted { a, b in
            if a.state != b.state {
                return a.state == .active && b.state == .pending
            }
            return (a.lastSeenAt ?? a.linkedAt) > (b.lastSeenAt ?? b.linkedAt)
        }
    }

    /// Contiguous-day completion streak ending at `anchor`. Today is a grace day
    /// (zero completions allowed); only past zero-completion days break the streak. Capped at 365.
    func currentStreak(asOf anchor: Date = .now) -> Int {
        let cal = Self.praccyCalendar
        let todayStart = cal.startOfDay(for: anchor)
        var streak = 0
        var cursor = todayStart
        var isToday = true
        for _ in 0..<365 {
            let dayEnd = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let predicate = #Predicate<PracticeTask> { task in
                task.isDone
                    && task.completedAt != nil
                    && task.completedAt! >= cursor
                    && task.completedAt! < dayEnd
            }
            let hasCompletion = (try? fetchCount(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? 0 > 0
            if hasCompletion {
                streak += 1
            } else if !isToday {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            isToday = false
        }
        return streak
    }

    /// Count of open (not-done) tasks assigned to a student. Derived at read time.
    func assignedTaskCount(for student: StudentLink) -> Int {
        let id = student.remoteStudentID
        let predicate = #Predicate<PracticeTask> { task in
            task.assignedTo != nil
                && task.assignedTo!.remoteStudentID == id
                && !task.isDone
        }
        return (try? fetchCount(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? 0
    }

    /// Assigned tasks for a student, undone first then `createdAt` descending.
    func assignedTasks(for student: StudentLink, includeDone: Bool = true) -> [PracticeTask] {
        let id = student.remoteStudentID
        let predicate: Predicate<PracticeTask>
        if includeDone {
            predicate = #Predicate<PracticeTask> { task in
                task.assignedTo != nil
                    && task.assignedTo!.remoteStudentID == id
            }
        } else {
            predicate = #Predicate<PracticeTask> { task in
                task.assignedTo != nil
                    && task.assignedTo!.remoteStudentID == id
                    && !task.isDone
            }
        }
        let all = (try? fetch(FetchDescriptor<PracticeTask>(predicate: predicate))) ?? []
        return all.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone && b.isDone }
            return a.createdAt > b.createdAt
        }
    }

    /// Teacher-authored goals for a student, active first then `createdAt` descending.
    func goals(for student: StudentLink) -> [Goal] {
        let id = student.remoteStudentID
        let predicate = #Predicate<Goal> { goal in
            goal.assignedTo != nil
                && goal.assignedTo!.remoteStudentID == id
        }
        let all = (try? fetch(FetchDescriptor<Goal>(predicate: predicate))) ?? []
        return all.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone && b.isDone }
            return a.createdAt > b.createdAt
        }
    }

    // MARK: - Shared calendar

    fileprivate static let praccyCalendar: Calendar = .current
}
