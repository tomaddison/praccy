import SwiftUI

struct PraccyPressStyle: ButtonStyle {
    var shadowColor: Color? = nil
    var shadowOffset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        PressBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset
        )
    }
}

extension ButtonStyle where Self == PraccyPressStyle {
    static var praccyPress: PraccyPressStyle { PraccyPressStyle() }
    static func praccyPress(offset: CGFloat) -> PraccyPressStyle {
        PraccyPressStyle(shadowOffset: offset)
    }
    static func praccyPress(shadow: Color, offset: CGFloat = 4) -> PraccyPressStyle {
        PraccyPressStyle(shadowColor: shadow, shadowOffset: offset)
    }

    static func praccyWhiteCardPress(_ palette: AccentPalette) -> PraccyPressStyle {
        PraccyPressStyle(shadowColor: palette.softShadow, shadowOffset: 3)
    }
}

// MARK: - Flat press (no shadow, no offset)

struct PraccyFlatPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FlatPressBody(
            label: configuration.label,
            isPressed: configuration.isPressed
        )
    }
}

extension ButtonStyle where Self == PraccyFlatPressStyle {
    static var praccyPressFlat: PraccyFlatPressStyle { PraccyFlatPressStyle() }
}

private struct FlatPressBody<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @State private var visiblePressed = false
    @State private var pressStart: Date?
    @State private var releaseTask: DispatchWorkItem?

    private let minHold: TimeInterval = 0.08

    var body: some View {
        label
            .opacity(visiblePressed ? 0.55 : 1)
            // Scoped so the snap doesn't clobber withAnimation changes on the label.
            .transaction(value: visiblePressed) { $0.animation = nil }
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    releaseTask?.cancel()
                    releaseTask = nil
                    visiblePressed = true
                    pressStart = Date()
                } else {
                    let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? minHold
                    pressStart = nil
                    let remaining = max(0, minHold - elapsed)
                    if remaining > 0 {
                        let task = DispatchWorkItem { visiblePressed = false }
                        releaseTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: task)
                    } else {
                        releaseTask?.cancel()
                        releaseTask = nil
                        visiblePressed = false
                    }
                }
            }
    }
}

// MARK: - Modifier form for non-Button tappables

struct PraccyPressModifier: ViewModifier {
    var isPressed: Bool
    var shadowColor: Color? = nil
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        PressBody(
            label: content,
            isPressed: isPressed,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset
        )
    }
}

extension View {
    func praccyPress(isPressed: Bool, offset: CGFloat = 4) -> some View {
        modifier(PraccyPressModifier(isPressed: isPressed, shadowOffset: offset))
    }
    func praccyPress(isPressed: Bool, shadow: Color, offset: CGFloat = 4) -> some View {
        modifier(PraccyPressModifier(isPressed: isPressed, shadowColor: shadow, shadowOffset: offset))
    }

    /// Matches `praccyWhiteCardPress` for non-button surfaces.
    func praccyWhiteCardShadow(_ palette: AccentPalette) -> some View {
        praccySolidShadow(color: palette.softShadow, offset: 3)
    }
}

// MARK: - Shared body
//
// `visiblePressed` latches `isPressed` for `minHold` so single-frame presses still paint a depressed frame.
private struct PressBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let shadowColor: Color?
    let shadowOffset: CGFloat

    @State private var visiblePressed = false
    @State private var pressStart: Date?
    @State private var releaseTask: DispatchWorkItem?

    private let minHold: TimeInterval = 0.08

    var body: some View {
        label
            .compositingGroup()
            .shadow(
                color: (shadowColor ?? .clear).opacity(visiblePressed ? 0 : 1),
                radius: 0,
                x: 0,
                y: visiblePressed ? 0 : shadowOffset
            )
            .offset(y: visiblePressed ? shadowOffset : 0)
            .transaction(value: visiblePressed) { $0.animation = nil }
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    releaseTask?.cancel()
                    releaseTask = nil
                    visiblePressed = true
                    pressStart = Date()
                } else {
                    let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? minHold
                    pressStart = nil
                    let remaining = max(0, minHold - elapsed)
                    if remaining > 0 {
                        let task = DispatchWorkItem { visiblePressed = false }
                        releaseTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: task)
                    } else {
                        releaseTask?.cancel()
                        releaseTask = nil
                        visiblePressed = false
                    }
                }
            }
    }
}
