import Foundation
import AVFoundation
import Observation
import os

// MARK: - Beat

/// Accent pattern (not time-signature). Downbeats click at 1200Hz, upbeats at 800Hz.
enum MetronomeBeat: Int, Codable, CaseIterable {
    case down
    case up
}

// MARK: - Render state

/// Audio-thread-safe render params. Scalars treated as atomic; `beats` uses
/// `OSAllocatedUnfairLock` since Array assignment isn't atomic.
private final class MetronomeRenderState: @unchecked Sendable {
    var bpm: Int = 100

    private let beatsLock = OSAllocatedUnfairLock<[MetronomeBeat]>(initialState: [.down, .up, .up, .up])
    var beats: [MetronomeBeat] {
        get { beatsLock.withLock { $0 } }
        set { beatsLock.withLock { $0 = newValue } }
    }

    // Audio-thread cursors; UI timer reads `publishedBeatIndex` non-atomically.
    var beatPhase: Int = 0
    var sinePhase: Double = 0
    var nextBeatIndex: Int = 0
    var currentFrequency: Double = 1500
    var publishedBeatIndex: Int = 0
}

// MARK: - Metronome

/// Real-time-synthesised metronome. No scheduling queue: bpm/beats changes take effect on the next click,
/// so audio and UI beat-dot stay locked.
@MainActor
@Observable
final class Metronome {
    // MARK: Tunables

    var bpm: Int = 100 {
        didSet { state.bpm = bpm }
    }
    var beats: [MetronomeBeat] = [.down, .up, .up, .up] {
        didSet { state.beats = beats }
    }

    private(set) var isPlaying = false
    /// 0-based index of the beat currently sounding. Mirrored from the audio thread at 60Hz.
    private(set) var currentBeatIndex: Int = 0

    static let minBPM = 30
    static let maxBPM = 220
    static let minBeats = 1
    static let maxBeats = 12

    // MARK: Audio

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let state = MetronomeRenderState()
    /// Pinned at first install; used to compute frames-per-beat off the audio thread.
    private var sampleRate: Double = 48_000

    private var displayTimer: Timer?

    // Tap tempo state - sliding window of recent tap timestamps.
    private var tapTimestamps: [Date] = []
    private static let tapWindowSize = 4
    private static let tapResetGap: TimeInterval = 2.0

    // MARK: Lifecycle

    init() {
        state.bpm = bpm
        state.beats = beats
    }

    // MARK: Control

    /// Builds the engine graph without starting audio so the first Play tap only pays for `engine.start()`.
    func prepare() {
        installSourceNodeIfNeeded()
    }

    func start() {
        guard !isPlaying else { return }
        configureAudioSession()
        installSourceNodeIfNeeded()
        // Anchor so the first downbeat fires on the first render frame.
        state.beatPhase = framesPerBeat()
        state.nextBeatIndex = 0
        state.sinePhase = 0
        state.publishedBeatIndex = 0

        do {
            try engine.start()
        } catch {
            return
        }
        isPlaying = true
        currentBeatIndex = 0

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.mirrorBeatIndex() }
        }
    }

    func stop() {
        guard isPlaying else { return }
        displayTimer?.invalidate()
        displayTimer = nil
        engine.stop()
        isPlaying = false
        currentBeatIndex = 0
    }

    func toggle() {
        isPlaying ? stop() : start()
    }

    // MARK: Beat editing

    func addBeat() {
        guard beats.count < Self.maxBeats else { return }
        beats.append(.up)
    }

    func removeBeat() {
        guard beats.count > Self.minBeats else { return }
        beats.removeLast()
    }

    func toggleBeat(at index: Int) {
        guard beats.indices.contains(index) else { return }
        beats[index] = beats[index] == .down ? .up : .down
    }

    // MARK: Tap tempo

    func tapTempo() {
        let now = Date()
        if let last = tapTimestamps.last, now.timeIntervalSince(last) > Self.tapResetGap {
            tapTimestamps.removeAll()
        }
        tapTimestamps.append(now)
        if tapTimestamps.count > Self.tapWindowSize {
            tapTimestamps.removeFirst(tapTimestamps.count - Self.tapWindowSize)
        }
        guard tapTimestamps.count >= 2 else { return }
        let intervals = zip(tapTimestamps.dropFirst(), tapTimestamps)
            .map { $0.timeIntervalSince($1) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return }
        let raw = Int((60.0 / avg).rounded())
        bpm = min(Self.maxBPM, max(Self.minBPM, raw))
    }

    // MARK: Tempo helpers

    /// Italian tempo marking (Grove-ish brackets).
    var tempoMarking: String { Self.tempoMarking(for: bpm) }

    static func tempoMarking(for bpm: Int) -> String {
        switch bpm {
        case ..<40: return "Grave"
        case 40..<60: return "Largo"
        case 60..<66: return "Larghetto"
        case 66..<76: return "Adagio"
        case 76..<108: return "Andante"
        case 108..<120: return "Moderato"
        case 120..<168: return "Allegro"
        case 168..<200: return "Vivace"
        default: return "Presto"
        }
    }

    // MARK: Private

    private func framesPerBeat() -> Int {
        Int((60.0 / Double(max(1, bpm))) * sampleRate)
    }

    private func mirrorBeatIndex() {
        guard isPlaying else { return }
        let live = state.publishedBeatIndex
        if live != currentBeatIndex && beats.indices.contains(live) {
            currentBeatIndex = live
        }
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let renderState = state
        let rate = sampleRate
        let twoPi = 2.0 * Double.pi
        // Clave-style percussive click: fast attack, exp decay, fundamental + 2nd partial.
        let clickFrameLength = Int(0.090 * rate)
        let decayRate: Double = 55.0
        let baselineAmp: Float = 0.9
        let partialMix: Double = 0.35
        let partialNorm: Double = 1.0 / (1.0 + partialMix)

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            // Snapshot tunables once per call so a mid-render change can't tear the period.
            let bpmSnapshot = max(1, renderState.bpm)
            let framesPerBeat = Int((60.0 / Double(bpmSnapshot)) * rate)
            let beatsSnapshot = renderState.beats
            let beatCount = max(1, beatsSnapshot.count)

            var beatPhase = renderState.beatPhase
            var sinePhase = renderState.sinePhase
            var nextIdx = renderState.nextBeatIndex
            var freq = renderState.currentFrequency
            var published = renderState.publishedBeatIndex

            for frame in 0..<frames {
                if beatPhase >= framesPerBeat {
                    let beatIdx = nextIdx % beatCount
                    let beatType = beatsSnapshot[beatIdx]
                    freq = beatType == .down ? 1200.0 : 800.0
                    published = beatIdx
                    nextIdx = (beatIdx + 1) % beatCount
                    beatPhase = 0
                    sinePhase = 0
                }

                var sample: Float = 0
                if beatPhase < clickFrameLength {
                    let t = Double(beatPhase) / rate
                    let envelope = exp(-decayRate * t)
                    let wave = (sin(sinePhase) + partialMix * sin(2.0 * sinePhase)) * partialNorm
                    sample = Float(wave * envelope) * baselineAmp
                    sinePhase += twoPi * freq / rate
                    if sinePhase > twoPi { sinePhase -= twoPi }
                }

                beatPhase += 1

                for buf in abl {
                    let ptr = buf.mData?.assumingMemoryBound(to: Float.self)
                    ptr?[frame] = sample
                }
            }

            renderState.beatPhase = beatPhase
            renderState.sinePhase = sinePhase
            renderState.nextBeatIndex = nextIdx
            renderState.currentFrequency = freq
            renderState.publishedBeatIndex = published
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    /// Idempotent re-arm. Interruptions (phone call, alarm) deactivate the app's launch session.
    private func configureAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }
}
