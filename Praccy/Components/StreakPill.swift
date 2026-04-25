import SwiftUI

/// Flame + count pill for the student header. Fixed orange palette, `ModelContext`-free
/// (caller passes `days`). Becomes a button when `onTap` is set.
struct StreakPill: View {
    let days: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                pillContent
            }
            .buttonStyle(.praccyPress(shadow: PraccyColor.streakOrangeShadow))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(days)-day streak")
            .accessibilityHint("Opens streak detail")
            .accessibilityAddTraits(.isButton)
        } else {
            pillContent
                .praccySolidShadow(color: PraccyColor.streakOrangeShadow)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(days)-day streak")
        }
    }

    /// Shadow is applied by the caller so `.praccyPress` can swallow it on press.
    private var pillContent: some View {
        HStack(spacing: 8) {
            PraccyIcon.view(for: .flame, tint: PraccyColor.streakFlame, size: 24)
            Text("\(days)")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PraccyColor.streakEgg, in: Capsule())
    }
}

#if DEBUG
#Preview("Streak pill") {
    HStack(spacing: 12) {
        StreakPill(days: 0)
        StreakPill(days: 7)
        StreakPill(days: 142)
    }
    .padding(24)
    .background(AccentPalette.violet.bg)
}
#endif
