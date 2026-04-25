import SwiftUI

/// Circular progress ring. Caller picks `color` + `track` for either on-accent or on-surface placement.
struct PraccyRing<Content: View>: View {
    var size: CGFloat = 56
    var stroke: CGFloat = 6
    var progress: Double
    var color: Color
    var track: Color = PraccyColor.ink08
    @ViewBuilder var content: () -> Content

    init(
        size: CGFloat = 56,
        stroke: CGFloat = 6,
        progress: Double,
        color: Color,
        track: Color = PraccyColor.ink08,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.size = size
        self.stroke = stroke
        self.progress = progress
        self.color = color
        self.track = track
        self.content = content
    }

    var body: some View {
        let clamped = max(0, min(1, progress))
        ZStack {
            Circle()
                .stroke(track, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: clamped)
            content()
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 32) {
        PraccyRing(size: 68, stroke: 9, progress: 0.33, color: .white, track: Color.white.opacity(0.25)) {
            Text("2/6").foregroundStyle(.white).font(PraccyFont.task)
        }
        .padding(24)
        .background(AccentPalette.violet.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.card))

        PraccyRing(size: 56, stroke: 6, progress: 0.7, color: AccentPalette.violet.accent)
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
    }
    .padding()
    .background(AccentPalette.violet.bg)
}
