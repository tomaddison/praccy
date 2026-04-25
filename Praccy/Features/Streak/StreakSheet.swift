import SwiftUI
import SwiftData

/// Streak celebration sheet with hero number, subtitle, and a medal pill for `bestStreak`.
/// `streak` is passed in so the sheet always matches the pill that opened it.
struct StreakSheet: View {
    let streak: Int
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsRows: [UserSettings]

    private var bestStreak: Int {
        max(settingsRows.first?.bestStreak ?? 0, streak)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            heroNumber

            Text(subtitleCopy)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink60)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 12)

            if bestStreak > 0 {
                bestBadge
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityLabel("Practice streak")
        .onAppear(perform: syncBestStreakIfNeeded)
    }

    // MARK: - Pieces

    /// `minimumScaleFactor` handles triple-digit streaks and AX sizing without truncating.
    private var heroNumber: some View {
        Text("\(streak)")
            .font(.custom("Nunito-Black", size: 180))
            .tracking(-6)
            .foregroundStyle(PraccyColor.streakFlame)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .accessibilityLabel("Current streak: \(streak) \(streak == 1 ? "day" : "days")")
    }

    private var bestBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "medal.fill")
                .font(.system(.title3, weight: .black))
                .foregroundStyle(PraccyColor.streakFlame)
            Text("Your best streak is \(bestStreak) \(bestStreak == 1 ? "day" : "days")")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.streakFlame)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(PraccyColor.streakEgg, in: Capsule())
        .praccySolidShadow(color: PraccyColor.streakOrangeShadow)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Copy

    private var subtitleCopy: String {
        if streak == 0 {
            return "Tick off a task today to start your streak."
        }
        return "You've practised \(streak) \(streak == 1 ? "day" : "days") in a row"
    }

    // MARK: - Backstop

    /// Backstop for new bests reached outside `HomeScreen.toggleCompletion` (seed, reconcile, migration).
    private func syncBestStreakIfNeeded() {
        let settings = UserSettings.current(in: modelContext)
        if streak > settings.bestStreak {
            settings.bestStreak = streak
            try? modelContext.save()
        }
    }
}

#if DEBUG
#Preview("Streak sheet - 7 days") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.bestStreak = 12
    return StreakSheet(streak: 7, palette: .violet)
        .modelContainer(container)
}

#Preview("Streak sheet - 0 days") {
    let container = PraccySchema.makeContainer(inMemory: true)
    return StreakSheet(streak: 0, palette: .violet)
        .modelContainer(container)
}

#Preview("Streak sheet - 1 day") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.bestStreak = 1
    return StreakSheet(streak: 1, palette: .violet)
        .modelContainer(container)
}

#Preview("Streak sheet - 142 days") {
    let container = PraccySchema.makeContainer(inMemory: true)
    let settings = UserSettings.current(in: container.mainContext)
    settings.bestStreak = 142
    return StreakSheet(streak: 142, palette: .violet)
        .modelContainer(container)
}
#endif
