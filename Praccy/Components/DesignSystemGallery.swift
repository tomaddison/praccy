#if DEBUG
import SwiftUI

/// DEBUG-only gallery of every design-system primitive, viewed via Xcode Previews.
struct DesignSystemGallery: View {
    private let palette: AccentPalette = .violet
    @State private var checkA = false
    @State private var checkB = true
    @State private var showConfetti = false
    @State private var progress: Double = 0.33
    @State private var studentTab: StudentTab = .home
    @State private var teacherTab: TeacherTab = .students

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                colourSwatches
                typographyRow
                buttonsAndPress
                ringsAndChecks
                mascots
                iconGrid
                chromeRow
            }
            .padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .foregroundStyle(PraccyColor.ink)
    }

    // MARK: Sections

    private var colourSwatches: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens").praccyEyebrow()
            HStack(spacing: 12) {
                swatch("Accent", palette.accent, onAccent: true)
                swatch("Surface", palette.surface, onAccent: false)
                swatch("Bg", palette.bg, onAccent: false)
                swatch("Shadow", palette.shadow, onAccent: true)
            }
        }
    }

    private func swatch(_ name: String, _ colour: Color, onAccent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 18)
                .fill(colour)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(PraccyColor.ink10, lineWidth: 1)
                )
            Text(name)
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
        }
    }

    private var typographyRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Type scale").praccyEyebrow()
            Text("Praccy.").praccyDisplay()
            Text("Let's play.").praccyTitle()
            Text("The big picture.").praccySection()
            Text("C major scale - hands together").praccyTask()
            Text("5 min · 14 day streak").praccyMeta()
            Text("today").praccyEyebrow()
        }
    }

    private var buttonsAndPress: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press").praccyEyebrow()
            Button {
                // no-op
            } label: {
                Text("Mark done")
                    .font(PraccyFont.task)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge))
            }
            .buttonStyle(.praccyPress(shadow: palette.shadow))
        }
    }

    private var ringsAndChecks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rings + checks").praccyEyebrow()
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: PraccyRadius.card)
                        .fill(palette.accent)
                    PraccyRing(
                        size: 68, stroke: 9, progress: progress,
                        color: .white, track: Color.white.opacity(0.25)
                    ) {
                        Text(progressLabel)
                            .font(PraccyFont.task)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 140, height: 140)
                .praccySolidShadow(color: palette.shadow)

                VStack(alignment: .leading, spacing: 12) {
                    PraccyCheck(isChecked: $checkA, accent: palette.accent)
                    PraccyCheck(isChecked: $checkB, accent: palette.accent)
                }

                VStack(spacing: 10) {
                    Button("Bump") { progress = min(1, progress + 0.2) }
                        .buttonStyle(.praccyPress)
                    Button("Confetti") { showConfetti = true }
                        .buttonStyle(.praccyPress)
                }
                .font(PraccyFont.meta)
            }
            .overlay {
                if showConfetti {
                    ConfettiBurst(accent: palette.accent) { showConfetti = false }
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var mascots: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo").praccyEyebrow()
            HStack(spacing: 20) {
                PraccyMascot(size: 92, mood: .sleepy, accent: palette.accent)
                PraccyMascot(size: 92, mood: .happy, accent: palette.accent)
                PraccyMascot(size: 92, mood: .excited, accent: palette.accent)
            }
        }
    }

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icons").praccyEyebrow()
            HStack(spacing: 18) {
                PraccyIcon.view(for: .home, tint: palette.accent)
                PraccyIcon.view(for: .calendar, tint: palette.accent)
                PraccyIcon.view(for: .toolkit, tint: palette.accent)
                PraccyIcon.view(for: .goals, tint: palette.accent)
                PraccyIcon.view(for: .students, tint: palette.accent)
                PraccyIcon.view(for: .flame, tint: PraccyColor.streakFlame)
                PraccyIcon.view(for: .mic, tint: palette.accent)
                PraccyIcon.view(for: .flag, tint: palette.accent)
                PraccyIcon.view(for: .clock, tint: palette.accent)
                PraccyIcon.view(for: .chevronRight, tint: palette.accent)
                PraccyIcon.view(for: .plus, tint: palette.accent)
                PraccyIcon.view(for: .check, tint: palette.accent)
                PraccyIcon.view(for: .settings, tint: palette.accent)
            }
        }
    }

    private var chromeRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Chrome").praccyEyebrow()

            HStack(spacing: 14) {
                StreakPill(days: 0)
                StreakPill(days: 14)
                StreakPill(days: 142)
            }

            PraccyHeader(role: .student, streak: 14, palette: palette, onSettings: {})
                .background(palette.bg, in: RoundedRectangle(cornerRadius: PraccyRadius.card))

            PraccyHeader(role: .teacher, streak: 0, palette: palette, onSettings: {})
                .background(palette.bg, in: RoundedRectangle(cornerRadius: PraccyRadius.card))

            VStack(spacing: 12) {
                PraccyTabBar(
                    tabs: StudentTab.allCases,
                    selection: $studentTab,
                    iconFor: \.icon,
                    labelFor: \.title,
                    palette: palette
                )
                PraccyTabBar(
                    tabs: TeacherTab.allCases,
                    selection: $teacherTab,
                    iconFor: \.icon,
                    labelFor: \.title,
                    palette: palette
                )
            }
            .padding(.horizontal, -14) // the tab bar already insets itself
        }
    }

    // MARK: Helpers

    private var progressLabel: String {
        let pct = Int((progress * 100).rounded())
        return "\(pct)%"
    }
}

#Preview("Design system") {
    DesignSystemGallery()
}
#endif
