import Foundation
import AVFoundation
import Observation

// MARK: - Recorder

/// `AVAudioRecorder` wrapper. Flips the session to `.playAndRecord` on start and
/// restores `.playback` on stop so metronome/tuner keep their session hot.
/// Files land at `Documents/recordings/{taskID}/{recordingID}.m4a`.
@MainActor
@Observable
final class Recorder {
    enum State: Equatable {
        case idle
        case preparing
        case recording
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Seconds since `start(for:)` succeeded.
    private(set) var elapsed: TimeInterval = 0
    /// 0…1 normalised meter level (−60dB → 0, 0dB → 1).
    private(set) var level: Float = 0

    private var recorder: AVAudioRecorder?
    private var pollTimer: Timer?
    private var startedAt: Date?
    private var currentURL: URL?

    // MARK: - Public API

    /// Starts an `.m4a` capture scoped to `taskID`. Returns the file URL, or `nil` on permission/session failure.
    @discardableResult
    func start(for taskID: UUID) async -> URL? {
        guard await ensurePermission() else {
            state = .denied
            return nil
        }

        state = .preparing

        let recordingID = UUID()
        let dir = Self.directory(for: taskID)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }

        let url = dir.appendingPathComponent("\(recordingID.uuidString).m4a")

        do {
            try configureSessionForRecord()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            guard r.record() else {
                state = .failed("Couldn't start recording.")
                return nil
            }
            recorder = r
            currentURL = url
            startedAt = .now
            elapsed = 0
            level = 0
            state = .recording
            startPolling()
            return url
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Stops the active recording. Returns saved file + duration, or `nil` if none active.
    @discardableResult
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let url = currentURL else {
            return nil
        }
        let duration = recorder.currentTime
        recorder.stop()
        stopPolling()
        self.recorder = nil
        currentURL = nil
        startedAt = nil
        elapsed = 0
        level = 0
        state = .idle
        restorePlaybackSession()
        return (url, duration)
    }

    /// Aborts an in-flight recording and deletes the partial file.
    func cancel() {
        guard let recorder else { return }
        let url = currentURL
        recorder.stop()
        if let url { try? FileManager.default.removeItem(at: url) }
        stopPolling()
        self.recorder = nil
        currentURL = nil
        startedAt = nil
        elapsed = 0
        level = 0
        state = .idle
        restorePlaybackSession()
    }

    // MARK: - File layout

    static func directory(for taskID: UUID) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent(taskID.uuidString, isDirectory: true)
    }

    // MARK: - Permission

    private func ensurePermission() async -> Bool {
        #if canImport(UIKit)
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        @unknown default: return false
        }
        #else
        return true
        #endif
    }

    // MARK: - Session

    private func configureSessionForRecord() throws {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)
        #endif
    }

    /// Reverts to the app-wide `.playback` category so metronome/tuner still emit on task-detail exit.
    private func restorePlaybackSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }

    // MARK: - Poll loop

    private func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        guard let recorder, let startedAt else { return }
        elapsed = -startedAt.timeIntervalSinceNow
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let clamped = max(-60, min(0, db))
        level = Float((clamped + 60) / 60)
    }
}
