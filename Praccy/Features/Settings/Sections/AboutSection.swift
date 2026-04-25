import SwiftUI

/// About / Privacy / Terms link stubs; rows share a single "Coming at launch." alert.
struct AboutSection: View {
    let palette: AccentPalette
    let onTap: () -> Void

    var body: some View {
        SettingsSectionCard(eyebrow: "About", palette: palette) {
            VStack(spacing: 4) {
                SettingsRow(label: "About Praccy", trailing: .chevron, action: onTap)
                Divider().overlay(palette.accent.opacity(0.12))
                SettingsRow(label: "Privacy", trailing: .chevron, action: onTap)
                Divider().overlay(palette.accent.opacity(0.12))
                SettingsRow(label: "Terms", trailing: .chevron, action: onTap)
            }
        }
    }
}

#if DEBUG
#Preview {
    AboutSection(palette: .violet) { }
        .padding(22)
        .background(AccentPalette.violet.bg)
}
#endif
