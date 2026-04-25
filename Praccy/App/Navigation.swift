import Foundation

// MARK: - Tab enums
//
// Two enums so the compiler refuses mismatched role ↔ tab pairings.

enum StudentTab: CaseIterable, Hashable {
    case home, calendar, toolkit, goals

    var title: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .toolkit: return "Toolkit"
        case .goals: return "Goals"
        }
    }

    var icon: PraccyIcon {
        switch self {
        case .home: return .home
        case .calendar: return .calendar
        case .toolkit: return .toolkit
        case .goals: return .goals
        }
    }
}

enum TeacherTab: CaseIterable, Hashable {
    case students, toolkit

    var title: String {
        switch self {
        case .students: return "Students"
        case .toolkit: return "Toolkit"
        }
    }

    var icon: PraccyIcon {
        switch self {
        case .students: return .students
        case .toolkit: return .toolkit
        }
    }
}
