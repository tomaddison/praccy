import SwiftUI

// MARK: - Tempo
//
// Metronome mascot. Coordinates come from a 100×100 SVG viewBox, scaled by `size`.

enum PraccyMascotMood {
    case happy, sleepy, excited
}

struct PraccyMascot: View {
    var size: CGFloat = 92
    var mood: PraccyMascotMood = .happy
    var accent: Color
    var swing: Bool = true
    /// Daily progress (0-1) exposed to VoiceOver. `nil` on surfaces that aren't day-state aware.
    var dailyProgress: Double? = nil

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 100  // scale factor

            // Body - rounded trapezoid
            let body = MascotBody().path(in: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
            ctx.fill(body, with: .color(accent))

            // Pendulum slot
            ctx.fill(
                Path(roundedRect: CGRect(x: 47*s, y: 22*s, width: 6*s, height: 44*s), cornerRadius: 3*s),
                with: .color(Color.black.opacity(0.15))
            )

            // Face panel
            ctx.fill(
                Path(roundedRect: CGRect(x: 34*s, y: 46*s, width: 32*s, height: 22*s), cornerRadius: 8*s),
                with: .color(Color.white.opacity(0.18))
            )

            // Eyes
            let eyeH: CGFloat = (mood == .sleepy) ? 1.5 : 6
            let eyeY: CGFloat = 54
            ctx.fill(
                Path(roundedRect: CGRect(x: 40*s, y: eyeY*s, width: 4.5*s, height: eyeH*s), cornerRadius: 2.25*s),
                with: .color(PraccyColor.ink)
            )
            ctx.fill(
                Path(roundedRect: CGRect(x: 55.5*s, y: eyeY*s, width: 4.5*s, height: eyeH*s), cornerRadius: 2.25*s),
                with: .color(PraccyColor.ink)
            )

            // Cheeks
            ctx.fill(
                Path(ellipseIn: CGRect(x: (36-3)*s, y: (64-3)*s, width: 6*s, height: 6*s)),
                with: .color(PraccyColor.cheek.opacity(0.6))
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: (64-3)*s, y: (64-3)*s, width: 6*s, height: 6*s)),
                with: .color(PraccyColor.cheek.opacity(0.6))
            )

            // Mouth
            var mouth = Path()
            switch mood {
            case .excited:
                mouth.move(to: CGPoint(x: 40*s, y: 68*s))
                mouth.addQuadCurve(to: CGPoint(x: 60*s, y: 68*s), control: CGPoint(x: 50*s, y: 80*s))
            case .sleepy:
                mouth.move(to: CGPoint(x: 43*s, y: 70*s))
                mouth.addQuadCurve(to: CGPoint(x: 57*s, y: 70*s), control: CGPoint(x: 50*s, y: 72*s))
            case .happy:
                mouth.move(to: CGPoint(x: 42*s, y: 68*s))
                mouth.addQuadCurve(to: CGPoint(x: 58*s, y: 68*s), control: CGPoint(x: 50*s, y: 75*s))
            }
            ctx.stroke(
                mouth,
                with: .color(PraccyColor.ink),
                style: StrokeStyle(lineWidth: 2.2*s, lineCap: .round)
            )

            // Top knob
            ctx.fill(
                Path(roundedRect: CGRect(x: 46*s, y: 6*s, width: 8*s, height: 6*s), cornerRadius: 2*s),
                with: .color(PraccyColor.ink.opacity(0.4))
            )
        }
        .frame(width: size, height: size)
        // `.id(mood)` rebuilds `Pendulum` on mood change so animation duration refreshes.
        .overlay(
            Pendulum(swing: swing, mood: mood)
                .id(mood)
                .frame(width: size, height: size)
        )
        .accessibilityElement()
        .accessibilityLabel("Tempo the metronome, \(mood.accessibilityWord)")
        .accessibilityValue(progressValue)
    }

    private var progressValue: String {
        guard let dailyProgress else { return "" }
        let pct = Int((dailyProgress * 100).rounded())
        return "\(pct) percent done today"
    }
}

private struct MascotBody: Shape {
    func path(in rect: CGRect) -> Path {
        // Scale the prototype's 100×100 path into `rect`.
        let s = rect.width / 100
        var p = Path()
        p.move(to: CGPoint(x: 32*s, y: 20*s))
        p.addCurve(
            to: CGPoint(x: 42*s, y: 10*s),
            control1: CGPoint(x: 32*s, y: 14*s),
            control2: CGPoint(x: 36*s, y: 10*s)
        )
        p.addLine(to: CGPoint(x: 58*s, y: 10*s))
        p.addCurve(
            to: CGPoint(x: 68*s, y: 20*s),
            control1: CGPoint(x: 64*s, y: 10*s),
            control2: CGPoint(x: 68*s, y: 14*s)
        )
        p.addLine(to: CGPoint(x: 82*s, y: 82*s))
        p.addCurve(
            to: CGPoint(x: 74*s, y: 92*s),
            control1: CGPoint(x: 83*s, y: 88*s),
            control2: CGPoint(x: 79*s, y: 92*s)
        )
        p.addLine(to: CGPoint(x: 26*s, y: 92*s))
        p.addCurve(
            to: CGPoint(x: 18*s, y: 82*s),
            control1: CGPoint(x: 21*s, y: 92*s),
            control2: CGPoint(x: 17*s, y: 88*s)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Swinging pendulum (overlay so it can rotate independently)

private struct Pendulum: View {
    var swing: Bool
    var mood: PraccyMascotMood = .happy

    @State private var leftward = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSwinging: Bool { swing && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 100
            ZStack {
                Rectangle()
                    .fill(PraccyColor.ink)
                    .frame(width: 2*s, height: 44*s)
                    .offset(x: 0, y: -22*s + 44*s / 2 - geo.size.height/2 + 44*s)

                Circle()
                    .fill(PraccyColor.ink)
                    .frame(width: 8*s, height: 8*s)
                    .offset(x: 0, y: 30*s - geo.size.height/2)
            }
            // Reduce Motion holds the pendulum at rest rather than freezing mid-swing.
            .rotationEffect(
                .degrees(reduceMotion ? 0 : (leftward ? -18 : 18)),
                anchor: UnitPoint(x: 0.5, y: 0.85)
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(
                isSwinging
                ? .easeInOut(duration: (mood == .sleepy) ? 2.3 : (mood == .excited) ? 0.6 : 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: leftward
            )
        }
        .onAppear { if isSwinging { leftward = true } }
        .allowsHitTesting(false)
    }
}

// MARK: - Accessibility helpers

private extension PraccyMascotMood {
    var accessibilityWord: String {
        switch self {
        case .happy: return "happy"
        case .sleepy: return "sleepy"
        case .excited: return "excited"
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PraccyMascot(mood: .sleepy, accent: AccentPalette.violet.accent)
        PraccyMascot(mood: .happy, accent: AccentPalette.violet.accent)
        PraccyMascot(mood: .excited, accent: AccentPalette.violet.accent)
    }
    .padding()
    .background(AccentPalette.violet.bg)
}
