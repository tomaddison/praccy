import SwiftUI

/// Row inside a `SettingsSectionCard`. `action == nil` = non-interactive.
struct SettingsRow: View {
    enum Trailing {
        case none
        case value(String)
        case chevron
        case valueAndChevron(String)
    }

    let label: String
    let trailing: Trailing
    let action: (() -> Void)?

    init(label: String, trailing: Trailing = .none, action: (() -> Void)? = nil) {
        self.label = label
        self.trailing = trailing
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                rowBody
            }
            .buttonStyle(.plain)
        } else {
            rowBody
        }
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch trailing {
            case .none:
                EmptyView()
            case .value(let text):
                Text(text)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
            case .chevron:
                PraccyIcon.view(for: .chevronRight, tint: PraccyColor.ink45, size: 14)
            case .valueAndChevron(let text):
                Text(text)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                PraccyIcon.view(for: .chevronRight, tint: PraccyColor.ink45, size: 14)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("Settings rows") {
    VStack(spacing: 0) {
        SettingsRow(label: "Email", trailing: .value("not signed in"))
        Divider()
        SettingsRow(label: "Instrument", trailing: .valueAndChevron("Piano")) { }
        Divider()
        SettingsRow(label: "About", trailing: .chevron) { }
    }
    .padding(18)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 26))
    .padding(22)
    .background(AccentPalette.violet.bg)
}
#endif
