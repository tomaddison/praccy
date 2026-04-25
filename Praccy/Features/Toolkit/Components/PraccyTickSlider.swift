import SwiftUI
import UIKit

/// Hand-rolled ruler picker. `ScrollView` + viewAligned had a fling-back bug on release, and
/// its inertia gives no per-integer haptic hooks during momentum.
struct PraccyTickSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let majorTickEvery: Int
    let palette: AccentPalette

    /// Pixels. 0 = first tick centred, `maxOffset` = last tick centred.
    @State private var offset: CGFloat = 0
    /// Offset at drag start; `nil` when idle.
    @State private var dragStartOffset: CGFloat?
    @State private var isPressed = false
    @State private var isDecelerating = false
    @State private var decelerationTask: Task<Void, Never>?
    @State private var feedback = UISelectionFeedbackGenerator()

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        majorTickEvery: Int = 10,
        palette: AccentPalette
    ) {
        self._value = value
        self.range = range
        self.majorTickEvery = majorTickEvery
        self.palette = palette
    }

    private let tickPitch: CGFloat = 7
    private let trackHeight: CGFloat = 56

    private var maxOffset: CGFloat {
        CGFloat(range.upperBound - range.lowerBound) * tickPitch
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ruler(size: geo.size)
                centreIndicator
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .mask(edgeFadeMask)
            .gesture(dragGesture)
            .onAppear {
                offset = offsetFor(value)
                feedback.prepare()
            }
            .onChange(of: value) { _, newValue in
                // External change (tap tempo, manual entry, persistence
                // restore). Skip while user is actively dragging or an
                // internal deceleration is already running - those paths
                // write `value` themselves and would otherwise spawn a
                // nested decelerate every time an integer tick crosses.
                guard dragStartOffset == nil, !isDecelerating else { return }
                let expected = offsetFor(newValue)
                if abs(offset - expected) > 0.5 {
                    decelerate(from: offset, to: expected)
                }
            }
            .onDisappear { decelerationTask?.cancel() }
        }
        .frame(height: trackHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Value")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    // MARK: - Ruler

    private func ruler(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let centreX = canvasSize.width / 2
            let midY = canvasSize.height / 2
            let halfVisible = centreX + tickPitch * 2

            for bpm in range.lowerBound...range.upperBound {
                let dx = CGFloat(bpm - range.lowerBound) * tickPitch - offset
                if abs(dx) > halfVisible { continue }

                let isMajor = bpm % majorTickEvery == 0
                let tickHeight: CGFloat = isMajor ? 22 : 12
                let tickWidth: CGFloat = isMajor ? 1.5 : 1
                let opacity: Double = isMajor ? 0.55 : 0.28

                let rect = CGRect(
                    x: centreX + dx - tickWidth / 2,
                    y: midY - tickHeight / 2,
                    width: tickWidth,
                    height: tickHeight
                )
                context.fill(Path(rect), with: .color(palette.accent.opacity(opacity)))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.18),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var centreIndicator: some View {
        Capsule()
            .fill(palette.accent)
            .frame(
                width: isPressed ? 4 : 2.5,
                height: isPressed ? 40 : 28
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
    }

    // MARK: - Drag + inertia

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if dragStartOffset == nil {
                    decelerationTask?.cancel()
                    dragStartOffset = offset
                    isPressed = true
                }
                guard let start = dragStartOffset else { return }
                // Dragging right pulls lower values to the centre - the
                // iOS camera/timer wheel convention.
                let proposed = start - drag.translation.width
                commit(offset: clamp(proposed))
            }
            .onEnded { drag in
                guard let start = dragStartOffset else {
                    isPressed = false
                    return
                }
                dragStartOffset = nil
                isPressed = false

                // predictedEndTranslation already encodes iOS's native
                // deceleration curve - same one UIScrollView uses when a
                // user flicks. Our job is just to glide there.
                let predicted = start - drag.predictedEndTranslation.width
                let target = snapToTick(clamp(predicted))

                if abs(target - offset) < 0.5 {
                    commit(offset: target)
                } else {
                    decelerate(from: offset, to: target)
                }
            }
    }

    private func decelerate(from start: CGFloat, to end: CGFloat) {
        decelerationTask?.cancel()
        let distance = end - start
        // Scales duration with distance so a short nudge settles quickly
        // and a long fling has room to breathe. Capped so extreme flings
        // still feel snappy.
        let duration: Double = min(0.7, max(0.22, Double(abs(distance)) / 700.0))
        let startDate = Date()

        isDecelerating = true
        decelerationTask = Task { @MainActor in
            defer { isDecelerating = false }
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startDate)
                let t = min(1.0, elapsed / duration)
                // Cubic ease-out - classic inertia-feel deceleration.
                let eased = 1.0 - pow(1.0 - t, 3.0)
                let current = start + distance * CGFloat(eased)
                commit(offset: current)
                if t >= 1.0 { break }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            if !Task.isCancelled {
                commit(offset: end)
            }
        }
    }

    private func commit(offset newOffset: CGFloat) {
        offset = newOffset
        let newValue = valueFor(newOffset)
        if newValue != value {
            value = newValue
            feedback.selectionChanged()
            feedback.prepare()
        }
    }

    private func snapToTick(_ o: CGFloat) -> CGFloat {
        (o / tickPitch).rounded() * tickPitch
    }

    private func clamp(_ o: CGFloat) -> CGFloat {
        max(0, min(maxOffset, o))
    }

    private func valueFor(_ o: CGFloat) -> Int {
        let idx = Int((o / tickPitch).rounded())
        return max(range.lowerBound, min(range.upperBound, range.lowerBound + idx))
    }

    private func offsetFor(_ v: Int) -> CGFloat {
        CGFloat(v - range.lowerBound) * tickPitch
    }
}

#if DEBUG
#Preview("Tick slider - violet") {
    @Previewable @State var bpm = 100
    return ZStack {
        AccentPalette.violet.bg.ignoresSafeArea()
        VStack(spacing: 24) {
            Text("\(bpm) BPM")
                .font(PraccyFont.title)
                .foregroundStyle(PraccyColor.ink)
            PraccyTickSlider(value: $bpm, in: 30...220, palette: .violet)
        }
        .padding(24)
    }
}
#endif
