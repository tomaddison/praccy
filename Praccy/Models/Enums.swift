import Foundation

// MARK: - UserRole

/// Which side of the teacher ↔ student loop the account is on.
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case student
    case teacher

    var id: String { rawValue }
}

// MARK: - LinkState

/// Lifecycle of a teacher ↔ student link. Backend is authoritative; locally we render the last synced state.
enum LinkState: String, Codable, CaseIterable {
    case pending
    case active
    case severed
}
