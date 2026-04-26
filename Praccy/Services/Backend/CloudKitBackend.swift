import CloudKit
import Foundation

/// Production `PraccyBackend`.
///
/// - **Public DB**: tiny short-lived `JoinCode` records map a code to a teacher's `CKShare.URL`.
/// - **Private DB** (per teacher): the `PraccyRoster` zone holds one `StudentLinkRecord` per student,
///   each with a `CKShare` rooted at it. Tasks/recordings hang off the link record via cascade ref.
///
/// Students accept the share and read via `CKDatabaseScope.shared`; they never write to the private DB.
///
/// Requires an iCloud container configured in entitlements + published public schema. Without it,
/// `accountStatus()` returns `.couldNotDetermine` and every call throws `.iCloudUnavailable`.
// `@unchecked Sendable`: the only stored state is `let container` (CKContainer is thread-safe)
// and reads/writes go through thread-safe `UserDefaults`. Adding mutable instance state without
// synchronisation would break this guarantee.
final class CloudKitBackend: PraccyBackend, @unchecked Sendable {

    // MARK: Types

    enum RecordType {
        static let joinCode = "JoinCode"
        static let studentLink = "StudentLinkRecord"
        static let assignedTask = "AssignedTask"
        static let assignedGoal = "AssignedGoal"
    }

    enum Field {
        static let code = "code"
        static let teacherUserRecordName = "teacherUserRecordName"
        static let teacherDisplayName = "teacherDisplayName"
        static let teacherShareURL = "teacherShareURL"
        static let expiresAt = "expiresAt"
        static let consumed = "consumed"

        static let studentUserRecordName = "studentUserRecordName"
        static let studentDisplayName = "studentDisplayName"
        static let studentInstrument = "studentInstrument"
        static let linkedAt = "linkedAt"
        static let state = "state"

        static let title = "title"
        static let subtitle = "subtitle"
        static let detail = "detail"
        static let targetMinutes = "targetMinutes"
        static let dueDate = "dueDate"
        static let goalTitle = "goalTitle"
        static let goalRef = "goalRef"
        static let teacherNote = "teacherNote"
        static let isDone = "isDone"
        static let completedAt = "completedAt"
        static let recordingAsset = "recordingAsset"
        static let linkRef = "linkRef"
    }

    static let rosterZoneName = "PraccyRoster"

    // MARK: State

    private let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
    }

    // MARK: Identity

    func currentUser() async throws -> PraccyUser? {
        try await requireAccount()
        let recordID = try await container.userRecordID()
        return PraccyUser(id: recordID.recordName, displayName: nil, email: nil)
    }

    func signIn(credentialIdentifier: String, displayName: String?, email: String?) async throws -> PraccyUser {
        try await requireAccount()
        let recordID = try await container.userRecordID()
        // CloudKit identity is authoritative; the Apple Sign-In id stays on UserSettings for display.
        return PraccyUser(id: recordID.recordName, displayName: displayName, email: email)
    }

    func signOut() async throws {
        // Nothing server-side to tear down: no push subscriptions registered, and change tokens
        // live in UserDefaults and are wiped by the caller alongside local state.
    }

    // MARK: Linking

    func generateJoinCode(teacherDisplayName: String) async throws -> JoinCode {
        try await requireAccount()

        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureZoneExists(zoneID: zoneID)

        // Pending StudentLinkRecord root; the share anchors here. On student accept, reconcile
        // updates `studentUserRecordName` and flips state to `.active`.
        let linkRecord = CKRecord(
            recordType: RecordType.studentLink,
            recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        )
        linkRecord[Field.state] = "pending" as CKRecordValue
        linkRecord[Field.linkedAt] = Date() as CKRecordValue

        let share = CKShare(rootRecord: linkRecord)
        share[CKShare.SystemFieldKey.title] = "Praccy student link" as CKRecordValue
        share.publicPermission = .none

        // Atomic save; the share URL is populated on first save.
        let (savedLink, savedShare) = try await saveRecordAndShare(linkRecord, share, in: privateDB)
        guard let shareURL = savedShare.url else {
            throw PraccyBackendError.underlying("Share URL unavailable.")
        }

        // Public discovery record. No dedupe; teachers generate codes often.
        let code = JoinCodeGenerator.generate()
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        let userRecordID = try await container.userRecordID()

        let codeRecord = CKRecord(recordType: RecordType.joinCode)
        codeRecord[Field.code] = code as CKRecordValue
        codeRecord[Field.teacherUserRecordName] = userRecordID.recordName as CKRecordValue
        codeRecord[Field.teacherDisplayName] = teacherDisplayName as CKRecordValue
        codeRecord[Field.teacherShareURL] = shareURL.absoluteString as CKRecordValue
        codeRecord[Field.expiresAt] = expiresAt as CKRecordValue
        codeRecord[Field.consumed] = 0 as CKRecordValue

        _ = try await publicDB.save(codeRecord)
        _ = savedLink

        return JoinCode(code: code, expiresAt: expiresAt)
    }

    func redeemJoinCode(_ raw: String) async throws -> TeacherLinkDescriptor {
        try await requireAccount()

        guard let normalised = JoinCodeGenerator.normalise(raw) else {
            throw PraccyBackendError.codeInvalidFormat
        }

        let predicate = NSPredicate(
            format: "%K == %@ AND %K == 0 AND %K > %@",
            Field.code, normalised,
            Field.consumed,
            Field.expiresAt, Date() as CVarArg
        )
        let query = CKQuery(recordType: RecordType.joinCode, predicate: predicate)
        let (matches, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        guard let first = matches.first else {
            throw PraccyBackendError.codeNotFound
        }

        let codeRecord: CKRecord
        switch first.1 {
        case .success(let record):
            codeRecord = record
        case .failure(let error):
            throw mapCKError(error)
        }

        guard let shareURLString = codeRecord[Field.teacherShareURL] as? String,
              let shareURL = URL(string: shareURLString) else {
            throw PraccyBackendError.underlying("Code is missing a share URL.")
        }

        // Programmatic share accept; no URL tap needed.
        let metadata = try await fetchShareMetadata(for: shareURL)
        let acceptedShare = try await acceptShare(metadata: metadata)

        // Best-effort mark consumed; a failed write still leaves the code effectively burned once accepted.
        codeRecord[Field.consumed] = 1 as CKRecordValue
        _ = try? await publicDB.save(codeRecord)

        let teacherUserID = codeRecord[Field.teacherUserRecordName] as? String ?? "unknown"
        let teacherName = codeRecord[Field.teacherDisplayName] as? String ?? "Teacher"

        return TeacherLinkDescriptor(
            remoteLinkID: acceptedShare.recordID.recordName,
            remoteTeacherID: teacherUserID,
            teacherDisplayName: teacherName,
            teacherInstrument: nil,
            linkedAt: Date()
        )
    }

    func unlink(remoteLinkID: String) async throws {
        // Teacher-side: delete StudentLinkRecord (cascades tasks + recordings).
        // Student-side: dropping participation is best-effort; teacher keeps history.
        try await requireAccount()
        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: remoteLinkID, zoneID: zoneID)
        do {
            _ = try await privateDB.deleteRecord(withID: recordID)
        } catch {
            // `.unknownItem` means this is a shared-DB link (student side); best-effort, leave it.
            if (error as? CKError)?.code != .unknownItem {
                throw mapCKError(error)
            }
        }
    }

    // MARK: Task sync

    func assignTask(_ payload: AssignedTaskPayload, toStudentRemoteID: String) async throws {
        try await requireAccount()

        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureZoneExists(zoneID: zoneID)

        let recordID = CKRecord.ID(recordName: payload.remoteID, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.assignedTask, recordID: recordID)
        record[Field.title] = payload.title as CKRecordValue
        record[Field.detail] = payload.detail as CKRecordValue
        if let targetMinutes = payload.targetMinutes {
            record[Field.targetMinutes] = targetMinutes as CKRecordValue
        }
        if let dueDate = payload.dueDate {
            record[Field.dueDate] = dueDate as CKRecordValue
        }
        if let goalRemoteID = payload.goalRemoteID {
            let goalRecordID = CKRecord.ID(recordName: goalRemoteID, zoneID: zoneID)
            record[Field.goalRef] = CKRecord.Reference(recordID: goalRecordID, action: .none)
        }
        if let goalTitle = payload.goalTitle {
            record[Field.goalTitle] = goalTitle as CKRecordValue
        }
        if let teacherNote = payload.teacherNote {
            record[Field.teacherNote] = teacherNote as CKRecordValue
        }
        record[Field.isDone] = (payload.isDone ? 1 : 0) as CKRecordValue
        if let completedAt = payload.completedAt {
            record[Field.completedAt] = completedAt as CKRecordValue
        }

        let linkRecordID = CKRecord.ID(recordName: payload.remoteLinkID, zoneID: zoneID)
        record[Field.linkRef] = CKRecord.Reference(recordID: linkRecordID, action: .deleteSelf)

        try await upsert(record: record, in: privateDB)
    }

    func removeTask(remoteTaskID: String) async throws {
        try await requireAccount()
        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: remoteTaskID, zoneID: zoneID)
        do {
            _ = try await privateDB.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw mapCKError(error)
        }
    }

    func markTaskComplete(remoteTaskID: String, completedAt: Date) async throws {
        try await requireAccount()
        let (record, database) = try await fetchAssignedRecord(
            recordType: RecordType.assignedTask,
            recordName: remoteTaskID
        )
        record[Field.isDone] = 1 as CKRecordValue
        record[Field.completedAt] = completedAt as CKRecordValue
        try await upsert(record: record, in: database)
    }

    func uploadRecording(fileURL: URL, forTaskRemoteID: String) async throws -> RecordingUploadResult {
        try await requireAccount()
        let (record, database) = try await fetchAssignedRecord(
            recordType: RecordType.assignedTask,
            recordName: forTaskRemoteID
        )
        record[Field.recordingAsset] = CKAsset(fileURL: fileURL)
        try await upsert(record: record, in: database)
        return RecordingUploadResult(remoteID: record.recordID.recordName, uploadedAt: .now)
    }

    // MARK: Goal sync

    func assignGoal(_ payload: AssignedGoalPayload, toStudentRemoteID: String) async throws {
        try await requireAccount()

        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureZoneExists(zoneID: zoneID)

        let recordID = CKRecord.ID(recordName: payload.remoteID, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.assignedGoal, recordID: recordID)
        record[Field.title] = payload.title as CKRecordValue
        record[Field.subtitle] = payload.subtitle as CKRecordValue
        if let dueDate = payload.dueDate {
            record[Field.dueDate] = dueDate as CKRecordValue
        }
        record[Field.isDone] = (payload.isDone ? 1 : 0) as CKRecordValue
        if let completedAt = payload.completedAt {
            record[Field.completedAt] = completedAt as CKRecordValue
        }

        let linkRecordID = CKRecord.ID(recordName: payload.remoteLinkID, zoneID: zoneID)
        record[Field.linkRef] = CKRecord.Reference(recordID: linkRecordID, action: .deleteSelf)

        try await upsert(record: record, in: privateDB)
    }

    func removeGoal(remoteGoalID: String) async throws {
        try await requireAccount()
        let zoneID = CKRecordZone.ID(zoneName: Self.rosterZoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: remoteGoalID, zoneID: zoneID)
        do {
            _ = try await privateDB.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw mapCKError(error)
        }
    }

    func markGoalComplete(remoteGoalID: String, completedAt: Date) async throws {
        try await requireAccount()
        let (record, database) = try await fetchAssignedRecord(
            recordType: RecordType.assignedGoal,
            recordName: remoteGoalID
        )
        record[Field.isDone] = 1 as CKRecordValue
        record[Field.completedAt] = completedAt as CKRecordValue
        try await upsert(record: record, in: database)
    }

    // MARK: Reconcile

    func reconcile() async throws -> ReconcileChangeSet {
        try await requireAccount()

        var accumulator = ReconcileAccumulator()

        try await reconcile(database: privateDB, scope: .private, into: &accumulator)
        try await reconcile(database: sharedDB, scope: .shared, into: &accumulator)

        return accumulator.buildChangeSet()
    }

    // MARK: - Helpers

    private func requireAccount() async throws {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw mapCKError(error)
        }
        switch status {
        case .available:
            return
        case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
            throw PraccyBackendError.iCloudUnavailable
        @unknown default:
            throw PraccyBackendError.iCloudUnavailable
        }
    }

    private func ensureZoneExists(zoneID: CKRecordZone.ID) async throws {
        do {
            _ = try await privateDB.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            _ = try await privateDB.save(CKRecordZone(zoneID: zoneID))
        } catch {
            throw mapCKError(error)
        }
    }

    private func saveRecordAndShare(
        _ record: CKRecord,
        _ share: CKShare,
        in database: CKDatabase
    ) async throws -> (CKRecord, CKShare) {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [record, share])
            operation.savePolicy = .ifServerRecordUnchanged

            var savedRecord: CKRecord?
            var savedShare: CKShare?
            var operationError: Error?

            operation.perRecordSaveBlock = { _, result in
                switch result {
                case .success(let saved):
                    if let share = saved as? CKShare {
                        savedShare = share
                    } else {
                        savedRecord = saved
                    }
                case .failure(let error):
                    operationError = error
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let record = savedRecord, let share = savedShare {
                        continuation.resume(returning: (record, share))
                    } else if let error = operationError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: PraccyBackendError.underlying("Share save returned no record."))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = true
            operation.qualityOfService = .userInitiated

            var metadata: CKShare.Metadata?
            var operationError: Error?

            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let fetched):
                    metadata = fetched
                case .failure(let error):
                    operationError = error
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata {
                        continuation.resume(returning: metadata)
                    } else if let operationError {
                        continuation.resume(throwing: operationError)
                    } else {
                        continuation.resume(throwing: PraccyBackendError.underlying("Missing share metadata."))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    private func acceptShare(metadata: CKShare.Metadata) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.qualityOfService = .userInitiated

            var accepted: CKShare?
            var operationError: Error?

            operation.perShareResultBlock = { _, result in
                switch result {
                case .success(let share):
                    accepted = share
                case .failure(let error):
                    // `.alreadyShared` means this device already accepted this share.
                    // The metadata's share is still valid for our purposes (recordID stable).
                    if let ckError = error as? CKError, ckError.code == .alreadyShared {
                        return
                    }
                    operationError = error
                }
            }

            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let accepted {
                        continuation.resume(returning: accepted)
                    } else if let operationError {
                        continuation.resume(throwing: operationError)
                    } else {
                        // Idempotent re-accept: per-share returned `.alreadyShared`
                        // and overall result was success. Use the metadata's share.
                        continuation.resume(returning: metadata.share)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    private func mapCKError(_ error: Error) -> PraccyBackendError {
        guard let ckError = error as? CKError else {
            return .underlying(error.localizedDescription)
        }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return .network
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .iCloudUnavailable
        case .unknownItem:
            return .codeNotFound
        default:
            return .underlying(ckError.localizedDescription)
        }
    }

    // MARK: - Record-level helpers

    /// Tolerates `.serverRecordChanged` as success; the queue's idempotent retry lane replays writes.
    private func upsert(record: CKRecord, in database: CKDatabase) async throws {
        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            return
        } catch {
            throw mapCKError(error)
        }
    }

    /// Tries `sharedDB` first (student is the primary mutator for complete + upload), then `privateDB`.
    private func fetchAssignedRecord(
        recordType: String,
        recordName: String
    ) async throws -> (CKRecord, CKDatabase) {
        for database in [sharedDB, privateDB] {
            let zones: [CKRecordZone]
            do {
                zones = try await database.allRecordZones()
            } catch let error as CKError where error.code == .zoneNotFound {
                continue
            }
            for zone in zones {
                let id = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
                do {
                    let record = try await database.record(for: id)
                    if record.recordType == recordType {
                        return (record, database)
                    }
                } catch let error as CKError where error.code == .unknownItem {
                    continue
                } catch {
                    throw mapCKError(error)
                }
            }
        }
        throw PraccyBackendError.underlying("Record not found: \(recordName)")
    }

    // MARK: - Reconcile plumbing

    private enum ReconcileScope {
        case `private`
        case shared
    }

    private struct ReconcileAccumulator {
        var upsertedTasks: [AssignedTaskPayload] = []
        var removedTaskRemoteIDs: [String] = []
        var upsertedGoals: [AssignedGoalPayload] = []
        var removedGoalRemoteIDs: [String] = []
        var upsertedTeacherLinks: [TeacherLinkDescriptor] = []
        var severedTeacherLinkRemoteIDs: [String] = []
        var upsertedStudentLinks: [StudentLinkDescriptor] = []
        var severedStudentLinkRemoteIDs: [String] = []

        func buildChangeSet() -> ReconcileChangeSet {
            ReconcileChangeSet(
                upsertedTasks: upsertedTasks,
                removedTaskRemoteIDs: removedTaskRemoteIDs,
                upsertedGoals: upsertedGoals,
                removedGoalRemoteIDs: removedGoalRemoteIDs,
                upsertedTeacherLinks: upsertedTeacherLinks,
                severedTeacherLinkRemoteIDs: severedTeacherLinkRemoteIDs,
                upsertedStudentLinks: upsertedStudentLinks,
                severedStudentLinkRemoteIDs: severedStudentLinkRemoteIDs
            )
        }
    }

    private func reconcile(
        database: CKDatabase,
        scope: ReconcileScope,
        into accumulator: inout ReconcileAccumulator
    ) async throws {
        let dbChanges = try await fetchDatabaseChanges(database: database, scope: scope)

        // On the student side only, a deleted zone = severed teacher link. Teacher-side severs come
        // in as `state="severed"` on the StudentLinkRecord itself.
        if scope == .shared {
            for zoneID in dbChanges.deletedZoneIDs {
                accumulator.severedTeacherLinkRemoteIDs.append(zoneID.zoneName)
            }
        }

        for zoneID in dbChanges.changedZoneIDs {
            try await fetchZoneChanges(
                database: database,
                scope: scope,
                zoneID: zoneID,
                into: &accumulator
            )
        }
    }

    private struct DatabaseChanges {
        var changedZoneIDs: [CKRecordZone.ID] = []
        var deletedZoneIDs: [CKRecordZone.ID] = []
    }

    private func fetchDatabaseChanges(
        database: CKDatabase,
        scope: ReconcileScope
    ) async throws -> DatabaseChanges {
        let tokenKey = Self.databaseTokenKey(scope: scope)
        var changes = DatabaseChanges()
        var token = loadToken(forKey: tokenKey)
        var more = true

        while more {
            let (fetched, newToken, hasMore, tokenExpired) = try await runDatabaseChangesOperation(
                database: database,
                previousToken: token
            )
            if tokenExpired {
                // Token rotated; retry from scratch.
                clearToken(forKey: tokenKey)
                token = nil
                continue
            }
            changes.changedZoneIDs.append(contentsOf: fetched.changedZoneIDs)
            changes.deletedZoneIDs.append(contentsOf: fetched.deletedZoneIDs)
            token = newToken
            more = hasMore
        }
        if let token { saveToken(token, forKey: tokenKey) }
        return changes
    }

    private func runDatabaseChangesOperation(
        database: CKDatabase,
        previousToken: CKServerChangeToken?
    ) async throws -> (DatabaseChanges, CKServerChangeToken?, Bool, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: previousToken)
            var changes = DatabaseChanges()
            var newToken: CKServerChangeToken?
            var moreComing = false
            var tokenExpired = false

            operation.recordZoneWithIDChangedBlock = { zoneID in
                changes.changedZoneIDs.append(zoneID)
            }
            operation.recordZoneWithIDWasDeletedBlock = { zoneID in
                changes.deletedZoneIDs.append(zoneID)
            }
            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success(let (token, more)):
                    newToken = token
                    moreComing = more
                    continuation.resume(returning: (changes, newToken, moreComing, tokenExpired))
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        tokenExpired = true
                        continuation.resume(returning: (changes, nil, false, true))
                    } else {
                        continuation.resume(throwing: self.mapCKError(error))
                    }
                }
            }
            database.add(operation)
        }
    }

    private func fetchZoneChanges(
        database: CKDatabase,
        scope: ReconcileScope,
        zoneID: CKRecordZone.ID,
        into accumulator: inout ReconcileAccumulator
    ) async throws {
        let tokenKey = Self.zoneTokenKey(zoneID: zoneID)
        var token = loadToken(forKey: tokenKey)
        var more = true

        while more {
            let (changed, deleted, newToken, hasMore, tokenExpired) = try await runZoneChangesOperation(
                database: database,
                zoneID: zoneID,
                previousToken: token
            )
            if tokenExpired {
                clearToken(forKey: tokenKey)
                token = nil
                continue
            }
            for record in changed {
                applyChangedRecord(record, scope: scope, into: &accumulator)
            }
            for (recordID, recordType) in deleted {
                applyDeletedRecord(recordID: recordID, recordType: recordType, into: &accumulator)
            }
            token = newToken
            more = hasMore
        }
        if let token { saveToken(token, forKey: tokenKey) }
    }

    private func runZoneChangesOperation(
        database: CKDatabase,
        zoneID: CKRecordZone.ID,
        previousToken: CKServerChangeToken?
    ) async throws -> ([CKRecord], [(CKRecord.ID, String)], CKServerChangeToken?, Bool, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                previousServerChangeToken: previousToken,
                resultsLimit: nil,
                desiredKeys: nil
            )
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            var changed: [CKRecord] = []
            var deleted: [(CKRecord.ID, String)] = []
            var newToken: CKServerChangeToken?
            var moreComing = false
            var tokenExpired = false

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    changed.append(record)
                }
            }
            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                deleted.append((recordID, recordType))
            }
            operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                newToken = token
            }
            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let (token, _, more)):
                    newToken = token
                    moreComing = more
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        tokenExpired = true
                    }
                }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (changed, deleted, newToken, moreComing, tokenExpired))
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        continuation.resume(returning: (changed, deleted, nil, false, true))
                    } else {
                        continuation.resume(throwing: self.mapCKError(error))
                    }
                }
            }
            database.add(operation)
        }
    }

    private func applyChangedRecord(
        _ record: CKRecord,
        scope: ReconcileScope,
        into accumulator: inout ReconcileAccumulator
    ) {
        switch record.recordType {
        case RecordType.studentLink:
            applyLinkRecord(record, scope: scope, into: &accumulator)
        case RecordType.assignedTask:
            if let payload = taskPayload(from: record) {
                accumulator.upsertedTasks.append(payload)
            }
        case RecordType.assignedGoal:
            if let payload = goalPayload(from: record) {
                accumulator.upsertedGoals.append(payload)
            }
        default:
            return
        }
    }

    private func applyDeletedRecord(
        recordID: CKRecord.ID,
        recordType: String,
        into accumulator: inout ReconcileAccumulator
    ) {
        switch recordType {
        case RecordType.assignedTask:
            accumulator.removedTaskRemoteIDs.append(recordID.recordName)
        case RecordType.assignedGoal:
            accumulator.removedGoalRemoteIDs.append(recordID.recordName)
        case RecordType.studentLink:
            // Mirror into both lists; SyncCoordinator picks the side by matching remoteLinkID.
            accumulator.severedTeacherLinkRemoteIDs.append(recordID.recordName)
            accumulator.severedStudentLinkRemoteIDs.append(recordID.recordName)
        default:
            return
        }
    }

    private func applyLinkRecord(
        _ record: CKRecord,
        scope: ReconcileScope,
        into accumulator: inout ReconcileAccumulator
    ) {
        let linkedAt = (record[Field.linkedAt] as? Date) ?? .now
        let state = (record[Field.state] as? String) ?? "active"

        if state == "severed" {
            accumulator.severedTeacherLinkRemoteIDs.append(record.recordID.recordName)
            accumulator.severedStudentLinkRemoteIDs.append(record.recordID.recordName)
            return
        }

        switch scope {
        case .shared:
            // Student reading teacher's zone. Display name is stamped at redeem time; reconcile just needs identity + linkedAt.
            let descriptor = TeacherLinkDescriptor(
                remoteLinkID: record.recordID.recordName,
                remoteTeacherID: record.recordID.zoneID.ownerName,
                teacherDisplayName: (record[Field.teacherDisplayName] as? String) ?? "Teacher",
                teacherInstrument: nil,
                linkedAt: linkedAt
            )
            accumulator.upsertedTeacherLinks.append(descriptor)
        case .private:
            let descriptor = StudentLinkDescriptor(
                remoteLinkID: record.recordID.recordName,
                remoteStudentID: (record[Field.studentUserRecordName] as? String) ?? "",
                studentDisplayName: (record[Field.studentDisplayName] as? String) ?? "Student",
                studentInstrument: record[Field.studentInstrument] as? String,
                linkedAt: linkedAt
            )
            accumulator.upsertedStudentLinks.append(descriptor)
        }
    }

    private func taskPayload(from record: CKRecord) -> AssignedTaskPayload? {
        guard let linkRef = record[Field.linkRef] as? CKRecord.Reference,
              let title = record[Field.title] as? String else {
            return nil
        }
        return AssignedTaskPayload(
            remoteID: record.recordID.recordName,
            remoteLinkID: linkRef.recordID.recordName,
            title: title,
            detail: (record[Field.detail] as? String) ?? "",
            targetMinutes: record[Field.targetMinutes] as? Int,
            dueDate: record[Field.dueDate] as? Date,
            goalRemoteID: (record[Field.goalRef] as? CKRecord.Reference)?.recordID.recordName,
            goalTitle: record[Field.goalTitle] as? String,
            teacherNote: record[Field.teacherNote] as? String,
            isDone: ((record[Field.isDone] as? Int) ?? 0) != 0,
            completedAt: record[Field.completedAt] as? Date
        )
    }

    private func goalPayload(from record: CKRecord) -> AssignedGoalPayload? {
        guard let linkRef = record[Field.linkRef] as? CKRecord.Reference,
              let title = record[Field.title] as? String else {
            return nil
        }
        return AssignedGoalPayload(
            remoteID: record.recordID.recordName,
            remoteLinkID: linkRef.recordID.recordName,
            title: title,
            subtitle: (record[Field.subtitle] as? String) ?? "",
            dueDate: record[Field.dueDate] as? Date,
            isDone: ((record[Field.isDone] as? Int) ?? 0) != 0,
            completedAt: record[Field.completedAt] as? Date
        )
    }

    // MARK: - Change token persistence

    private static func databaseTokenKey(scope: ReconcileScope) -> String {
        switch scope {
        case .private: return "praccy.changeToken.db.private"
        case .shared: return "praccy.changeToken.db.shared"
        }
    }

    private static func zoneTokenKey(zoneID: CKRecordZone.ID) -> String {
        "praccy.changeToken.zone.\(zoneID.ownerName).\(zoneID.zoneName)"
    }

    private func loadToken(forKey key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveToken(_ token: CKServerChangeToken, forKey key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        ) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func clearToken(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
