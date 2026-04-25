import SwiftUI

// MARK: - PraccyIcon
//
// Centralised icon set. Call `PraccyIcon.view(for:)` from feature code rather than picking SF Symbols directly.

enum PraccyIcon {
    // Tab bar
    case home, calendar, toolkit, goals, students

    // Inline
    case flame, mic, flag, clock, chevronRight, chevronLeft, chevronDown
    case plus, check, settings, mascotKnob, xmark

    // Toolkit
    case tuningFork, metronome, speakerWave, play, stop, minus

    @ViewBuilder
    static func view(for icon: PraccyIcon, tint: Color = PraccyColor.ink, size: CGFloat = 22) -> some View {
        switch icon {
        case .home:
            TabHomeShape()
                .stroke(tint, style: .tabIconStroke(size: size))
                .frame(width: size, height: size)
        case .calendar:
            TabCalendarShape()
                .stroke(tint, style: .tabIconStroke(size: size))
                .frame(width: size, height: size)
        case .toolkit:
            TabToolkitShape(tint: tint, size: size)
                .frame(width: size, height: size)
        case .goals:
            TabGoalsShape(tint: tint, size: size)
                .frame(width: size, height: size)
        case .students:
            Image(systemName: "person.2")
                .font(.system(size: size * 0.95, weight: .semibold))
                .foregroundStyle(tint)
        case .flame:
            FlameShape()
                .fill(tint)
                .frame(width: size * (16.0/18.0), height: size)
        case .mic:
            Image(systemName: "mic.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        case .flag:
            FlagShape()
                .fill(tint)
                .frame(width: size * (12.0/14.0), height: size)
        case .clock:
            Image(systemName: "clock.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .chevronRight:
            Image(systemName: "chevron.right")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .chevronLeft:
            Image(systemName: "chevron.left")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .chevronDown:
            Image(systemName: "chevron.down")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .plus:
            Image(systemName: "plus")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .settings:
            Image(systemName: "gearshape.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .xmark:
            Image(systemName: "xmark")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .mascotKnob:
            Image(systemName: "music.note")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .tuningFork:
            Image(systemName: "tuningfork")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .metronome:
            Image(systemName: "metronome.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .speakerWave:
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .play:
            Image(systemName: "play.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .stop:
            Image(systemName: "stop.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        case .minus:
            Image(systemName: "minus")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Tab icon shapes

extension StrokeStyle {
    /// Stroke proportional to icon size so line weight is consistent at any render size.
    static func tabIconStroke(size: CGFloat) -> StrokeStyle {
        StrokeStyle(
            lineWidth: max(1.4, size * 1.8 / 22),
            lineCap: .round,
            lineJoin: .round
        )
    }
}

struct TabHomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 22
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.move(to: p(3, 11))
        path.addLine(to: p(11, 4))
        path.addLine(to: p(19, 11))
        path.addLine(to: p(19, 18))
        path.addQuadCurve(to: p(17, 20), control: p(19, 20))
        path.addLine(to: p(14, 20))
        path.addLine(to: p(14, 14))
        path.addLine(to: p(8, 14))
        path.addLine(to: p(8, 20))
        path.addLine(to: p(5, 20))
        path.addQuadCurve(to: p(3, 18), control: p(3, 20))
        path.closeSubpath()
        return path
    }
}

struct TabCalendarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 22
        var path = Path()
        let body = CGRect(x: 3*s, y: 5*s, width: 16*s, height: 14*s)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3*s, height: 3*s))
        path.move(to: CGPoint(x: 3*s, y: 9*s))
        path.addLine(to: CGPoint(x: 19*s, y: 9*s))
        path.move(to: CGPoint(x: 7*s, y: 3*s))
        path.addLine(to: CGPoint(x: 7*s, y: 7*s))
        path.move(to: CGPoint(x: 15*s, y: 3*s))
        path.addLine(to: CGPoint(x: 15*s, y: 7*s))
        return path
    }
}

/// Mixed stroke + fill, so it's a `View` rather than a `Shape`.
struct TabToolkitShape: View {
    let tint: Color
    let size: CGFloat

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 22
            let stroke = StrokeStyle.tabIconStroke(size: size)

            var body = Path()
            body.addRoundedRect(
                in: CGRect(x: 3*s, y: 8*s, width: 16*s, height: 11*s),
                cornerSize: CGSize(width: 2.5*s, height: 2.5*s)
            )
            ctx.stroke(body, with: .color(tint), style: stroke)

            var handle = Path()
            handle.move(to: CGPoint(x: 8*s, y: 8*s))
            handle.addLine(to: CGPoint(x: 8*s, y: 6*s))
            handle.addQuadCurve(
                to: CGPoint(x: 14*s, y: 6*s),
                control: CGPoint(x: 11*s, y: 2*s)
            )
            handle.addLine(to: CGPoint(x: 14*s, y: 8*s))
            ctx.stroke(handle, with: .color(tint), style: stroke)

            let dot = Path(ellipseIn: CGRect(
                x: (11 - 1.5) * s, y: (13.5 - 1.5) * s,
                width: 3*s, height: 3*s
            ))
            ctx.fill(dot, with: .color(tint))
        }
        .frame(width: size, height: size)
    }
}

struct TabGoalsShape: View {
    let tint: Color
    let size: CGFloat

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 22
            let stroke = StrokeStyle.tabIconStroke(size: size)

            let outer = Path(ellipseIn: CGRect(
                x: (11 - 8) * s, y: (11 - 8) * s,
                width: 16*s, height: 16*s
            ))
            ctx.stroke(outer, with: .color(tint), style: stroke)

            let inner = Path(ellipseIn: CGRect(
                x: (11 - 4.5) * s, y: (11 - 4.5) * s,
                width: 9*s, height: 9*s
            ))
            ctx.stroke(inner, with: .color(tint), style: stroke)

            let centre = Path(ellipseIn: CGRect(
                x: (11 - 1.5) * s, y: (11 - 1.5) * s,
                width: 3*s, height: 3*s
            ))
            ctx.fill(centre, with: .color(tint))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Custom shapes

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 16
        let sy = rect.height / 18
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        var path = Path()
        path.move(to: p(8, 1))
        path.addCurve(to: p(12, 9), control1: p(9, 4), control2: p(12, 5))
        path.addCurve(to: p(8, 14), control1: p(12, 12), control2: p(10, 14))
        path.addCurve(to: p(4, 9), control1: p(6, 14), control2: p(4, 12))
        path.addCurve(to: p(6, 6), control1: p(4, 7), control2: p(5, 6))
        path.addCurve(to: p(8, 8), control1: p(6, 8), control2: p(7, 8))
        path.addCurve(to: p(8, 1), control1: p(8, 6), control2: p(6, 5))
        path.closeSubpath()
        return path
    }
}

struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 12
        let sy = rect.height / 14
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        var path = Path()
        path.addRect(CGRect(x: p(1.5, 1).x, y: p(1.5, 1).y, width: 1*sx, height: 12*sy))
        path.move(to: p(2, 2))
        path.addLine(to: p(9, 2))
        path.addLine(to: p(7.5, 4.5))
        path.addLine(to: p(9, 7))
        path.addLine(to: p(2, 7))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            PraccyIcon.view(for: .home, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .calendar, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .toolkit, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .goals, tint: AccentPalette.violet.accent)
        }
        HStack(spacing: 16) {
            PraccyIcon.view(for: .flame, tint: PraccyColor.streakFlame)
            PraccyIcon.view(for: .mic, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .flag, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .clock, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .chevronRight, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .plus, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .check, tint: AccentPalette.violet.accent)
            PraccyIcon.view(for: .settings, tint: AccentPalette.violet.accent)
        }
    }
    .padding()
    .background(AccentPalette.violet.bg)
}
