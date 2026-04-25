import SwiftUI

struct ProgressCard: View {
    let palette: AccentPalette
    let done: Int
    let total: Int
    let progress: Double

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private var pctDone: Int { Int(round(progress * 100)) }
    private var leftCount: Int { max(0, total - done) }

    var body: some View {
        HStack(spacing: 18) {
            PraccyRing(
                size: 68,
                stroke: 9,
                progress: progress,
                color: .white,
                track: Color.white.opacity(0.25)
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(done)")
                        .font(PraccyFont.section)
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                    Text("/\(total)")
                        .font(PraccyFont.meta)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: .now))
                    .font(PraccyFont.section)
                    .tracking(-0.3)
                    .foregroundStyle(.white)
                Text("\(leftCount) left · \(pctDone)% done")
                    .font(PraccyFont.meta)
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow)
        .accessibilityElement()
        .accessibilityLabel("\(done) of \(total) done today, \(pctDone) percent")
    }
}
