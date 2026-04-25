import SwiftUI

/// Round checkbox with spring tick-in. `accent` is ring/fill, `onColor` is the tick.
struct PraccyCheck: View {
    @Binding var isChecked: Bool
    var size: CGFloat = 28
    var accent: Color
    var onColor: Color = .white
    var onToggle: (() -> Void)? = nil

    var body: some View {
        Button {
            onToggle?()
            isChecked.toggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(accent, lineWidth: 2.5)
                Circle()
                    .fill(accent)
                    .opacity(isChecked ? 1 : 0)
                TickShape()
                    .stroke(
                        onColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .scaleEffect(isChecked ? 1 : 0.5)
                    .opacity(isChecked ? 1 : 0)
            }
            .frame(width: size, height: size)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.praccyPress)
        .accessibilityLabel(isChecked ? "Done" : "Not done")
        .accessibilityAddTraits(.isButton)
    }
}

private struct TickShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 3/16, y: h * 8/16))
        p.addLine(to: CGPoint(x: w * 7/16, y: h * 12/16))
        p.addLine(to: CGPoint(x: w * 13/16, y: h * 4/16))
        return p
    }
}

#Preview {
    struct Demo: View {
        @State private var a = false
        @State private var b = true
        var body: some View {
            HStack(spacing: 28) {
                PraccyCheck(isChecked: $a, accent: AccentPalette.violet.accent)
                PraccyCheck(isChecked: $b, accent: AccentPalette.violet.accent)
                PraccyCheck(
                    isChecked: $b,
                    size: 40,
                    accent: .white,
                    onColor: AccentPalette.violet.accent
                )
                .padding()
                .background(AccentPalette.violet.accent)
            }
            .padding()
            .background(AccentPalette.violet.bg)
        }
    }
    return Demo()
}
