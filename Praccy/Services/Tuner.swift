import Foundation
import AVFoundation
import Observation

// MARK: - Note

/// 12 equal-temperament pitch classes. Stored as display strings for readable persistence.
enum TunerNote: String, CaseIterable, Identifiable, Codable {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "D#"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "G#"
    case a = "A"
    case aSharp = "A#"
    case b = "B"

    var id: String { rawValue }

    /// 0 = C … 11 = B.
    var semitoneIndex: Int {
        switch self {
        case .c: return 0
        case .cSharp: return 1
        case .d: return 2
        case .dSharp: return 3
        case .e: return 4
        case .f: return 5
        case .fSharp: return 6
        case .g: return 7
        case .gSharp: return 8
        case .a: return 9
        case .aSharp: return 10
        case .b: return 11
        }
    }
}

// MARK: - Render state

/// Audio-thread render params. Torn reads produce one glitched sample (inaudible for a drone).
private final class TunerRenderState: @unchecked Sendable {
    var targetFrequency: Double = 440
    /// 0 = silence, ~0.35 = listening level. Ramped toward.
    var targetAmplitude: Float = 0
    var currentAmplitude: Float = 0
    var phase: Double = 0
}

// MARK: - Tuner

/// Drone tuner. Sustains a sine tone at the picked pitch. No mic/pitch detection.
@MainActor
@Observable
final class Tuner {
    // MARK: Tunables

    var note: TunerNote = .a {
        didSet { applyFrequency() }
    }
    var octave: Int = 4 {
        didSet { applyFrequency() }
    }
    var referenceFrequency: Double = 440 {
        didSet { applyFrequency() }
    }

    private(set) var isPlaying = false

    var currentFrequency: Double {
        Self.frequency(for: note, octave: octave, reference: referenceFrequency)
    }

    // MARK: Audio

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let state = TunerRenderState()
    private var sampleRate: Double = 48_000

    private static let playingAmplitude: Float = 0.35

    /// 30ms linear fade in/out, avoiding click artefacts without feeling laggy.
    private static let rampSeconds: Double = 0.030

    // MARK: Lifecycle

    init() {
        state.targetFrequency = currentFrequency
    }

    // MARK: Control

    /// Builds the engine graph without starting audio, so the first Play tap only pays for `engine.start()`.
    func prepare() {
        installSourceNodeIfNeeded()
    }

    func start() {
        guard !isPlaying else { return }
        configureAudioSession()
        installSourceNodeIfNeeded()
        state.targetFrequency = currentFrequency
        state.targetAmplitude = Self.playingAmplitude
        do {
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        guard isPlaying else { return }
        // Ramp to silence, then tear down after the envelope drains (~30ms ramp + flush headroom).
        state.targetAmplitude = 0
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            engine.stop()
            isPlaying = false
        }
    }

    func toggle() {
        isPlaying ? stop() : start()
    }

    // MARK: Private

    private func applyFrequency() {
        state.targetFrequency = currentFrequency
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }
        let output = engine.mainMixerNode.outputFormat(forBus: 0)
        sampleRate = output.sampleRate
        let renderState = state
        let rate = sampleRate
        let rampPerFrame = Float(1.0 / (rate * Self.rampSeconds))

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = 2.0 * Double.pi

            var phase = renderState.phase
            var amp = renderState.currentAmplitude
            let target = renderState.targetAmplitude
            let freq = renderState.targetFrequency
            let phaseIncrement = twoPi * freq / rate

            let frames = Int(frameCount)
            for frame in 0..<frames {
                if amp < target {
                    amp = min(target, amp + rampPerFrame)
                } else if amp > target {
                    amp = max(target, amp - rampPerFrame)
                }
                let sample = Float(sin(phase)) * amp
                phase += phaseIncrement
                if phase > twoPi { phase -= twoPi }

                for buf in abl {
                    let ptr = buf.mData?.assumingMemoryBound(to: Float.self)
                    ptr?[frame] = sample
                }
            }

            renderState.phase = phase
            renderState.currentAmplitude = amp
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: output)
        sourceNode = node
    }

    /// Idempotent re-arm. Interruptions (call, alarm) deactivate the launch-time session.
    private func configureAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }

    // MARK: - Frequency math

    /// Equal-temperament Hz anchored to a user-selectable A4 reference (e.g. baroque 415, standard 440).
    static func frequency(for note: TunerNote, octave: Int, reference: Double) -> Double {
        let midi = 12 * (octave + 1) + note.semitoneIndex
        return reference * pow(2.0, Double(midi - 69) / 12.0)
    }
}
