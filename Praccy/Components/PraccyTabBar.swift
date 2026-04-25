import SwiftUI

/// Full-width tab bar generic over any `Hashable` tab enum; role-agnostic.
struct PraccyTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let iconFor: (Tab) -> PraccyIcon
    let labelFor: (Tab) -> String
    let palette: AccentPalette

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    @ViewBuilder
    private func tabButton(for tab: Tab) -> some View {
        let isActive = tab == selection
        Button {
                selection = tab
        } label: {
            VStack(spacing: 4) {
                PraccyIcon.view(
                    for: iconFor(tab),
                    tint: isActive ? palette.onAccent : PraccyColor.ink45,
                    size: 20
                )
                Text(labelFor(tab))
                    .font(PraccyFont.eyebrow.weight(.bold))
                    .tracking(-0.1)
                    .textCase(nil)
                    .foregroundStyle(isActive ? palette.onAccent : PraccyColor.ink45)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: PraccyRadius.tab)
                    .fill(isActive ? palette.accent : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: PraccyRadius.tab))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(labelFor(tab))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#if DEBUG
private struct TabBarPreviewHost<Tab: Hashable>: View {
    let tabs: [Tab]
    @State var selection: Tab
    let iconFor: (Tab) -> PraccyIcon
    let labelFor: (Tab) -> String
    let palette: AccentPalette

    var body: some View {
        PraccyTabBar(
            tabs: tabs,
            selection: $selection,
            iconFor: iconFor,
            labelFor: labelFor,
            palette: palette
        )
    }
}

#Preview("Tab bar - student") {
    VStack {
        Spacer()
        TabBarPreviewHost(
            tabs: StudentTab.allCases,
            selection: StudentTab.home,
            iconFor: \.icon,
            labelFor: \.title,
            palette: .violet
        )
        .padding(.bottom, 2)
    }
    .background(AccentPalette.violet.bg)
}

#Preview("Tab bar - teacher") {
    VStack {
        Spacer()
        TabBarPreviewHost(
            tabs: TeacherTab.allCases,
            selection: TeacherTab.students,
            iconFor: \.icon,
            labelFor: \.title,
            palette: .violet
        )
        .padding(.bottom, 2)
    }
    .background(AccentPalette.violet.bg)
}
#endif
