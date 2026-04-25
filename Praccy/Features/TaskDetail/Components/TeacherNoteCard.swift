import SwiftUI

struct TeacherNoteCard: View {
    let teacherName: String?
    let note: String
    let palette: AccentPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(teacherName.map { "Note from \($0)" } ?? "Note from your teacher")
                .praccyEyebrow()
                .foregroundStyle(palette.accent)
            Text(note)
                .font(PraccyFont.task)
                .foregroundStyle(PraccyColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card - 6))
        .overlay(
            RoundedRectangle(cornerRadius: PraccyRadius.card - 6)
                .stroke(PraccyColor.ink05, lineWidth: 1.5)
        )
    }
}
