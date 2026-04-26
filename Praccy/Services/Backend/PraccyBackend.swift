import Foundation

/// Transport layer for teacher ↔ student sync. `CloudKitBackend` in release; `MockBackend` in DEBUG.
/// Trades only in DTOs; SwiftData reads/writes belong to `SyncCoordinator`.
/// Transient failures throw `PraccyBackendError.network` so `BackendOperationQueue` can retry.
protocol PraccyBackend: Sendable {
    // MARK: Identity

    /// `nil` if signed out. Does not trigger a sign-in.
    func currentUser() async throws -> PraccyUser?

    /// `credentialIdentifier` is `ASAuthorizationAppleIDCredential.user` (stable across installs).
    /// Name/email only supplied on first sign-in per Apple's rules.
    func signIn(credentialIdentifier: String, displayName: String?, email: String?) async throws -> PraccyUser

    /// Caller wipes model rows after this returns.
    func signOut() async throws

    // MARK: Linking

    /// Teacher-only. Publishes a 6-char code and returns it. `teacherDisplayName` is
    /// written to the public record so the student sees who generated it.
    func generateJoinCode(teacherDisplayName: String) async throws -> JoinCode

    /// Student-only. Normalises + looks up the code and forms the link.
    func redeemJoinCode(_ raw: String) async throws -> TeacherLinkDescriptor

    /// Severs a link; the other side learns on its next reconcile. History is preserved.
    func unlink(remoteLinkID: String) async throws

    // MARK: Task sync

    /// Teacher-only. Pushes a new or updated assignment.
    func assignTask(_ payload: AssignedTaskPayload, toStudentRemoteID: String) async throws

    /// Teacher-only. Idempotent. Recordings on the student side stay in history.
    func removeTask(remoteTaskID: String) async throws

    /// Student-only. Idempotent and safe for the offline queue to retry.
    func markTaskComplete(remoteTaskID: String, completedAt: Date) async throws

    /// Student-only. Uploads an `.m4a` from `Recorder` to the teacher's side of the link.
    func uploadRecording(fileURL: URL, forTaskRemoteID: String) async throws -> RecordingUploadResult

    // MARK: Goal sync

    /// Teacher-only. Idempotent.
    func assignGoal(_ payload: AssignedGoalPayload, toStudentRemoteID: String) async throws

    /// Teacher-only. Tasks that laddered up to the goal lose their pin but stay in history.
    func removeGoal(remoteGoalID: String) async throws

    func markGoalComplete(remoteGoalID: String, completedAt: Date) async throws

    // MARK: Reconcile

    /// Pull remote changes. Caller applies the change set into SwiftData.
    func reconcile() async throws -> ReconcileChangeSet
}

// MARK: - Identity DTOs

struct PraccyUser: Sendable, Equatable, Codable {
    let id: String
    let displayName: String?
    let email: String?
}

// MARK: - Linking DTOs

struct JoinCode: Sendable, Equatable {
    let code: String
    let expiresAt: Date
}

struct TeacherLinkDescriptor: Sendable, Equatable {
    let remoteLinkID: String
    let remoteTeacherID: String
    let teacherDisplayName: String
    let teacherInstrument: String?
    let linkedAt: Date
}

struct StudentLinkDescriptor: Sendable, Equatable {
    let remoteLinkID: String
    let remoteStudentID: String
    let studentDisplayName: String
    let studentInstrument: String?
    let linkedAt: Date
}

// MARK: - Task DTOs

struct AssignedTaskPayload: Sendable, Equatable, Codable {
    let remoteID: String
    let remoteLinkID: String
    let title: String
    let detail: String
    let targetMinutes: Int?
    let dueDate: Date?
    /// Prefer this over `goalTitle`; the title is a fallback for surfaces that don't resolve the goal.
    let goalRemoteID: String?
    let goalTitle: String?
    let teacherNote: String?
    let isDone: Bool
    let completedAt: Date?
}

struct AssignedGoalPayload: Sendable, Equatable, Codable {
    let remoteID: String
    let remoteLinkID: String
    let title: String
    let subtitle: String
    let dueDate: Date?
    let isDone: Bool
    let completedAt: Date?
}

struct RecordingUploadResult: Sendable, Equatable {
    let remoteID: String
    let uploadedAt: Date
}

// MARK: - Reconcile

struct ReconcileChangeSet: Sendable, Equatable {
    let upsertedTasks: [AssignedTaskPayload]
    let removedTaskRemoteIDs: [String]
    let upsertedGoals: [AssignedGoalPayload]
    let removedGoalRemoteIDs: [String]
    let upsertedTeacherLinks: [TeacherLinkDescriptor]
    let severedTeacherLinkRemoteIDs: [String]
    let upsertedStudentLinks: [StudentLinkDescriptor]
    let severedStudentLinkRemoteIDs: [String]

    nonisolated static let empty = ReconcileChangeSet(
        upsertedTasks: [],
        removedTaskRemoteIDs: [],
        upsertedGoals: [],
        removedGoalRemoteIDs: [],
        upsertedTeacherLinks: [],
        severedTeacherLinkRemoteIDs: [],
        upsertedStudentLinks: [],
        severedStudentLinkRemoteIDs: []
    )
}

// MARK: - Errors

enum PraccyBackendError: Error, Equatable, LocalizedError {
    case notSignedIn
    case iCloudUnavailable
    case codeInvalidFormat
    case codeNotFound
    case codeExpired
    case codeAlreadyConsumed
    case network
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to continue."
        case .iCloudUnavailable:
            return "Sign into iCloud in Settings to use Praccy."
        case .codeInvalidFormat:
            return "Codes are 6 characters. Double-check the one you have."
        case .codeNotFound:
            return "That code doesn't match a teacher."
        case .codeExpired:
            return "This code has expired. Ask your teacher for a new one."
        case .codeAlreadyConsumed:
            return "This code has already been used."
        case .network:
            return "We couldn't reach the server. Check your connection and try again."
        case .underlying(let message):
            return message
        }
    }
}
