import Foundation
import SwiftData

/// Audio capture for a practice task. File lives at `Documents/recordings/{taskID}/{id}.m4a`;
/// the local file is the source of truth for playback regardless of upload state.
@Model
final class Recording {
    @Attribute(.unique) var id: UUID
    var fileURL: URL
    var duration: TimeInterval
    var createdAt: Date

    /// `nil` = on-device only.
    var uploadedAt: Date?

    /// Inverse declared on `PracticeTask.recordings` with cascade delete.
    var task: PracticeTask?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        duration: TimeInterval,
        createdAt: Date = .now,
        uploadedAt: Date? = nil,
        task: PracticeTask? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.duration = duration
        self.createdAt = createdAt
        self.uploadedAt = uploadedAt
        self.task = task
    }
}
