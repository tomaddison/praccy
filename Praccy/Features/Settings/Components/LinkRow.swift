import SwiftUI

/// Avatar + name + instrument + Unlink pill. Shared by student + teacher link sections.
struct LinkRow: View {
    let name: String
    let instrument: String?
    let palette: AccentPalette
    let onUnlink: () -> Void

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(palette.surface)
                Text(initial)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(PraccyColor.ink)
                    .lineLimit(1)
                if let instrument, !instrument.isEmpty {
                    Text(instrument)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onUnlink) {
                Text("Unlink")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.warning)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.chip)
                            .fill(Color.white)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: PraccyRadius.chip)
                            .strokeBorder(PraccyColor.warning, lineWidth: 1.5)
                    }
            }
            .buttonStyle(.praccyPress(offset: 2))
            .accessibilityLabel("Unlink \(name)")
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        LinkRow(name: "Claire Jensen", instrument: "Piano", palette: .violet) { }
        LinkRow(name: "Mo", instrument: nil, palette: .violet) { }
    }
    .padding(22)
    .background(AccentPalette.violet.bg)
}
#endif
