import Foundation

/// Persistent actor-gated queue for outbound writes that must survive airplane-mode flights.
/// Transient errors (`.network`, `.iCloudUnavailable`) leave the op in place; permanent errors
/// drop it so a poison pill can't wedge the queue. Backed by JSON at `Documents/.praccy-queue.json`.
actor BackendOperationQueue {

    enum Operation: Sendable, Codable, Equatable {
        case markTaskComplete(remoteTaskID: String, completedAt: Date)
        case uploadRecording(fileURLPath: String, remoteTaskID: String, localRecordingID: UUID)
        case assignTask(payload: AssignedTaskPayload, toStudentRemoteID: String)
        case assignGoal(payload: AssignedGoalPayload, toStudentRemoteID: String)
        case removeGoal(remoteGoalID: String)
    }

    private let backend: any PraccyBackend
    private let storeURL: URL
    private var pending: [Operation] = []
    private var isDraining: Bool = false

    /// Fires on upload success so the caller can stamp `Recording.uploadedAt` locally.
    var onRecordingUploaded: (@Sendable (UUID, RecordingUploadResult) async -> Void)?

    init(backend: any PraccyBackend, storeURL: URL? = nil) {
        self.backend = backend
        self.storeURL = storeURL ?? Self.defaultStoreURL()
        self.pending = Self.loadFromDisk(at: self.storeURL)
    }

    // MARK: Public API

    func enqueue(_ operation: Operation) {
        pending.append(operation)
        persist()
        Task { await drain() }
    }

    func setRecordingUploadedHandler(_ handler: @escaping @Sendable (UUID, RecordingUploadResult) async -> Void) {
        self.onRecordingUploaded = handler
    }

    /// Callers nudge on foreground in case the previous drain stopped on a transient error.
    func drainIfNeeded() async {
        await drain()
    }

    var pendingCount: Int { pending.count }

    // MARK: Drain

    private func drain() async {
        guard !isDraining else { return }
        guard !pending.isEmpty else { return }
        isDraining = true
        defer { isDraining = false }

        while let next = pending.first {
            do {
                try await execute(next)
                _ = pending.removeFirst()
                persist()
            } catch let error as PraccyBackendError where isTransient(error) {
                return
            } catch {
                _ = pending.removeFirst()
                persist()
            }
        }
    }

    private func execute(_ op: Operation) async throws {
        switch op {
        case .markTaskComplete(let remoteTaskID, let completedAt):
            try await backend.markTaskComplete(remoteTaskID: remoteTaskID, completedAt: completedAt)
        case .uploadRecording(let path, let remoteTaskID, let localRecordingID):
            let url = URL(fileURLWithPath: path)
            let result = try await backend.uploadRecording(fileURL: url, forTaskRemoteID: remoteTaskID)
            if let handler = onRecordingUploaded {
                await handler(localRecordingID, result)
            }
        case .assignTask(let payload, let studentRemoteID):
            try await backend.assignTask(payload, toStudentRemoteID: studentRemoteID)
        case .assignGoal(let payload, let studentRemoteID):
            try await backend.assignGoal(payload, toStudentRemoteID: studentRemoteID)
        case .removeGoal(let remoteGoalID):
            try await backend.removeGoal(remoteGoalID: remoteGoalID)
        }
    }

    private func isTransient(_ error: PraccyBackendError) -> Bool {
        switch error {
        case .network, .iCloudUnavailable, .notSignedIn:
            return true
        default:
            return false
        }
    }

    // MARK: Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Persist failures are tolerated; the queue lives in-memory for this session.
        }
    }

    private static func loadFromDisk(at url: URL) -> [Operation] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Operation].self, from: data)) ?? []
    }

    private static func defaultStoreURL() -> URL {
        let documents = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent(".praccy-queue.json")
    }
}
