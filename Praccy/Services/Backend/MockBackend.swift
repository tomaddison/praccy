import Foundation

/// In-memory `PraccyBackend` for previews and DEBUG. Single-process: two simulators
/// running `MockBackend` do NOT see each other; use `CloudKitBackend` for cross-device work.
actor MockBackend: PraccyBackend {

    // MARK: State

    private var signedInUser: PraccyUser?
    private var codes: [String: StoredCode] = [:]
    private var teacherLinks: [String: TeacherLinkDescriptor] = [:]
    private var studentLinks: [String: StudentLinkDescriptor] = [:]
    private var assignedTasks: [String: AssignedTaskPayload] = [:]
    private var assignedGoals: [String: AssignedGoalPayload] = [:]

    private struct StoredCode {
        var code: JoinCode
        var teacherUserID: String
        var teacherDisplayName: String
        var teacherInstrument: String?
        var consumed: Bool
    }

    /// Pre-seed state so previews can exercise redemption without running a full teacher flow first.
    struct Seed: Sendable {
        var currentUser: PraccyUser?
        var preIssuedCode: JoinCode?
        var preIssuedCodeTeacherName: String?

        static let signedInStudent = Seed(
            currentUser: PraccyUser(id: "mock.student", displayName: "Luca", email: nil)
        )
        static let signedInTeacher = Seed(
            currentUser: PraccyUser(id: "mock.teacher", displayName: "Claire", email: nil)
        )
    }

    init(seed: Seed? = nil) {
        guard let seed else { return }
        self.signedInUser = seed.currentUser
        if let preIssued = seed.preIssuedCode {
            codes[preIssued.code] = StoredCode(
                code: preIssued,
                teacherUserID: "mock.preseeded.teacher",
                teacherDisplayName: seed.preIssuedCodeTeacherName ?? "Claire",
                teacherInstrument: nil,
                consumed: false
            )
        }
    }

    // MARK: Identity

    func currentUser() async throws -> PraccyUser? { signedInUser }

    func signIn(credentialIdentifier: String, displayName: String?, email: String?) async throws -> PraccyUser {
        let user = PraccyUser(id: credentialIdentifier, displayName: displayName, email: email)
        signedInUser = user
        return user
    }

    func signOut() async throws {
        signedInUser = nil
    }

    // MARK: Linking

    func generateJoinCode(teacherDisplayName: String) async throws -> JoinCode {
        guard let user = signedInUser else { throw PraccyBackendError.notSignedIn }
        let code = JoinCode(
            code: JoinCodeGenerator.generate(),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        codes[code.code] = StoredCode(
            code: code,
            teacherUserID: user.id,
            teacherDisplayName: teacherDisplayName,
            teacherInstrument: nil,
            consumed: false
        )
        return code
    }

    func redeemJoinCode(_ raw: String) async throws -> TeacherLinkDescriptor {
        guard let normalised = JoinCodeGenerator.normalise(raw) else {
            throw PraccyBackendError.codeInvalidFormat
        }
        guard var stored = codes[normalised] else {
            throw PraccyBackendError.codeNotFound
        }
        if stored.consumed {
            throw PraccyBackendError.codeAlreadyConsumed
        }
        if stored.code.expiresAt < .now {
            throw PraccyBackendError.codeExpired
        }
        stored.consumed = true
        codes[normalised] = stored

        let descriptor = TeacherLinkDescriptor(
            remoteLinkID: UUID().uuidString,
            remoteTeacherID: stored.teacherUserID,
            teacherDisplayName: stored.teacherDisplayName,
            teacherInstrument: stored.teacherInstrument,
            linkedAt: .now
        )
        teacherLinks[descriptor.remoteLinkID] = descriptor
        return descriptor
    }

    func unlink(remoteLinkID: String) async throws {
        teacherLinks.removeValue(forKey: remoteLinkID)
        studentLinks.removeValue(forKey: remoteLinkID)
        assignedTasks = assignedTasks.filter { $0.value.remoteLinkID != remoteLinkID }
        assignedGoals = assignedGoals.filter { $0.value.remoteLinkID != remoteLinkID }
    }

    // MARK: Task sync

    func assignTask(_ payload: AssignedTaskPayload, toStudentRemoteID: String) async throws {
        assignedTasks[payload.remoteID] = payload
    }

    func markTaskComplete(remoteTaskID: String, completedAt: Date) async throws {
        guard let existing = assignedTasks[remoteTaskID] else { return }
        assignedTasks[remoteTaskID] = AssignedTaskPayload(
            remoteID: existing.remoteID,
            remoteLinkID: existing.remoteLinkID,
            title: existing.title,
            detail: existing.detail,
            targetMinutes: existing.targetMinutes,
            dueDate: existing.dueDate,
            goalRemoteID: existing.goalRemoteID,
            goalTitle: existing.goalTitle,
            teacherNote: existing.teacherNote,
            isDone: true,
            completedAt: completedAt
        )
    }

    func uploadRecording(fileURL: URL, forTaskRemoteID: String) async throws -> RecordingUploadResult {
        // Simulated latency so DEBUG UI sees a non-instant resolution.
        try await Task.sleep(for: .milliseconds(200))
        return RecordingUploadResult(remoteID: UUID().uuidString, uploadedAt: .now)
    }

    // MARK: Goal sync

    func assignGoal(_ payload: AssignedGoalPayload, toStudentRemoteID: String) async throws {
        assignedGoals[payload.remoteID] = payload
    }

    func removeGoal(remoteGoalID: String) async throws {
        assignedGoals.removeValue(forKey: remoteGoalID)
    }

    func markGoalComplete(remoteGoalID: String, completedAt: Date) async throws {
        guard let existing = assignedGoals[remoteGoalID] else { return }
        assignedGoals[remoteGoalID] = AssignedGoalPayload(
            remoteID: existing.remoteID,
            remoteLinkID: existing.remoteLinkID,
            title: existing.title,
            subtitle: existing.subtitle,
            dueDate: existing.dueDate,
            isDone: true,
            completedAt: completedAt
        )
    }

    // MARK: Reconcile

    func reconcile() async throws -> ReconcileChangeSet {
        // Process-local state; no remote changes ever arrive.
        .empty
    }
}
