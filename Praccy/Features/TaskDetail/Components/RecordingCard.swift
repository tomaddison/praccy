import SwiftUI
import SwiftData
import AVFoundation
import UIKit

/// Three-state card on the task detail screen: idle, recording, playback.
/// Self-contained: owns recorder/player + SwiftData writes for new takes.
struct RecordingCard: View {
    let task: PracticeTask
    let palette: AccentPalette
    let modelContext: ModelContext
    var role: UserRole = .student

    @Environment(\.backendQueue) private var queue
    @State private var recorder = Recorder()
    @State private var playback: PlaybackController? = nil
    @State private var errorMessage: String? = nil
    @State private var showingDeleteConfirm: Bool = false

    private enum Mode { case idle, recording, playback }

    private var latestRecording: Recording? {
        task.recordings
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var mode: Mode {
        if recorder.state == .recording || recorder.state == .preparing {
            return .recording
        }
        if latestRecording != nil { return .playback }
        return .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recording")
                .font(PraccyFont.section)
                .tracking(-0.3)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(PraccyFont.meta)
                .foregroundStyle(Color.white.opacity(0.85))
                .contentTransition(.opacity)
                .id(mode)

            Group {
                if role == .teacher {
                    teacherContent
                } else {
                    studentContent
                }
            }
            .padding(.top, 18)

            if let errorMessage {
                Text(errorMessage)
                    .font(PraccyFont.meta)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow)
        .onDisappear {
            // Mid-capture saves; mid-playback stops.
            if recorder.state == .recording { finaliseRecording() }
            playback?.stop()
        }
        .alert(
            "Delete recording?",
            isPresented: $showingDeleteConfirm,
            actions: {
                Button("Delete", role: .destructive) {
                    deleteLatestRecording()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                Button("Cancel", role: .cancel) { }
            },
            message: { Text("This can't be undone.") }
        )
    }

    private var subtitle: String {
        if role == .teacher {
            return latestRecording == nil
                ? "Student hasn't recorded yet."
                : "Student's latest take."
        }
        switch mode {
        case .idle: return "Tap to record your play."
        case .recording: return "Listening…"
        case .playback: return "Saved to your recordings."
        }
    }

    @ViewBuilder
    private var studentContent: some View {
        switch mode {
        case .idle:
            IdleControls(
                palette: palette,
                denied: recorder.state == .denied,
                onStart: startRecording
            )
        case .recording:
            RecordingControls(
                recorder: recorder,
                onStop: stopRecording
            )
        case .playback:
            if let rec = latestRecording {
                PlaybackRow(
                    recording: rec,
                    palette: palette,
                    playback: playbackController(for: rec),
                    onRerecord: rerecord,
                    onDelete: { showingDeleteConfirm = true }
                )
            }
        }
    }

    @ViewBuilder
    private var teacherContent: some View {
        if let rec = latestRecording {
            PlaybackRow(
                recording: rec,
                palette: palette,
                playback: playbackController(for: rec)
            )
        }
    }

    // MARK: - Actions

    private func startRecording() {
        errorMessage = nil
        Task {
            _ = await recorder.start(for: task.id)
            if case .failed(let message) = recorder.state {
                errorMessage = message
            }
        }
    }

    private func stopRecording() {
        finaliseRecording()
    }

    private func finaliseRecording() {
        guard let result = recorder.stop() else { return }
        let rec = Recording(
            fileURL: result.url,
            duration: result.duration,
            task: task
        )
        modelContext.insert(rec)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        enqueueUpload(recordingID: rec.id, fileURL: result.url)
    }

    private func enqueueUpload(recordingID: UUID, fileURL: URL) {
        guard let queue, let remoteID = task.remoteID else { return }
        Task {
            await queue.enqueue(.uploadRecording(
                fileURLPath: fileURL.path,
                remoteTaskID: remoteID,
                localRecordingID: recordingID
            ))
        }
    }

    private func rerecord() {
        deleteLatestRecording()
        startRecording()
    }

    private func deleteLatestRecording() {
        playback?.stop()
        playback = nil
        if let rec = latestRecording {
            try? FileManager.default.removeItem(at: rec.fileURL)
            modelContext.delete(rec)
            try? modelContext.save()
        }
    }

    private func playbackController(for recording: Recording) -> PlaybackController {
        if let existing = playback, existing.url == recording.fileURL {
            return existing
        }
        let controller = PlaybackController(url: recording.fileURL)
        playback = controller
        return controller
    }
}

// MARK: - Idle controls

private struct IdleControls: View {
    let palette: AccentPalette
    let denied: Bool
    let onStart: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onStart) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 10, height: 10)
                    Text("Start recording")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(palette.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card - 8))
            }
            .buttonStyle(.praccyPress(shadow: PraccyColor.ink10))
            .accessibilityLabel("Start recording")

            if denied {
                Button(action: openAppSettings) {
                    VStack(spacing: 4) {
                        Text("Mic access is off")
                            .font(PraccyFont.meta)
                            .foregroundStyle(Color.white)
                        Text("Open Settings to enable")
                            .font(PraccyFont.meta)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .underline()
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mic access is off. Open Settings to enable.")
                .accessibilityHint("Opens iOS Settings")
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Recording controls

private struct RecordingControls: View {
    let recorder: Recorder
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                PulsingDot()
                Text(Self.formatElapsed(recorder.elapsed))
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                LiveWaveform(level: recorder.level)
                    .frame(width: 72, height: 28)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                Color(hex: 0xFF5A3C),
                in: RoundedRectangle(cornerRadius: PraccyRadius.card - 8)
            )
            .praccySolidShadow(color: Color(hex: 0x8A2F1F), offset: 3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recording, \(Int(recorder.elapsed)) seconds")

            Button(action: onStop) {
                Text("Stop")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        PraccyColor.ink,
                        in: RoundedRectangle(cornerRadius: PraccyRadius.card - 8)
                    )
            }
            .buttonStyle(.praccyPress(shadow: Color.black.opacity(0.3)))
            .accessibilityLabel("Stop recording")
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PulsingDot: View {
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .scaleEffect(reduceMotion ? 1 : (pulsing ? 1.25 : 1))
            .opacity(reduceMotion ? (pulsing ? 0.5 : 1) : 1)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

/// Live mic-level waveform. Reduce Motion falls back to a static pattern.
private struct LiveWaveform: View {
    let level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let patterns: [CGFloat] = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.3, 0.7, 0.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/24.0)) { ctx in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<Self.patterns.count, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .frame(width: 3, height: barHeight(i: i, time: ctx.date))
                }
            }
        }
    }

    private func barHeight(i: Int, time: Date) -> CGFloat {
        let maxH: CGFloat = 28
        let base = Self.patterns[i]
        if reduceMotion { return base * maxH * 0.9 }
        let t = time.timeIntervalSinceReferenceDate
        let phase = sin(t * 3 + Double(i) * 0.6) * 0.25 + 0.75
        let boost = CGFloat(max(0.15, level))
        let h = base * CGFloat(phase) * boost * maxH * 1.6
        return max(4, min(maxH, h))
    }
}

// MARK: - Playback controller

/// Observable `AVAudioPlayer` wrapper; auto-stops on end-of-file.
@Observable
@MainActor
final class PlaybackController: NSObject, AVAudioPlayerDelegate {
    let url: URL
    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    init(url: URL) {
        self.url = url
        super.init()
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        if player == nil {
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.delegate = self
            p.prepareToPlay()
            player = p
        }
        guard let player else { return }
        if player.play() {
            isPlaying = true
            startTimer()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        progress = 0
        stopTimer()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.stopTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let player else { return }
        let d = player.duration
        progress = d > 0 ? player.currentTime / d : 0
    }
}
