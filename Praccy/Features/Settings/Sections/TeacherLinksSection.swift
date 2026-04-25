import SwiftUI
import SwiftData

/// Teacher-role-only: Add-student code generator + My-students list. Parallel to the Students tab.
struct TeacherLinksSection: View {
    let links: [StudentLink]
    let palette: AccentPalette
    let onRequestUnlink: (StudentLink) -> Void

    @Environment(\.backend) private var backend
    @Query private var settingsRows: [UserSettings]

    @State private var generatedCode: JoinCode?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?

    private var teacherDisplayName: String {
        let name = settingsRows.first?.displayName ?? ""
        return name.isEmpty ? "Teacher" : name
    }

    var body: some View {
        VStack(spacing: 18) {
            addStudentCard
            myStudentsCard
        }
    }

    private var addStudentCard: some View {
        SettingsSectionCard(eyebrow: "Add student", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                if let generatedCode {
                    Text(generatedCode.code)
                        .font(PraccyFont.display)
                        .tracking(8)
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                                .fill(palette.surface)
                        )
                        .accessibilityLabel("New student code: \(generatedCode.code.map { String($0) }.joined(separator: " "))")

                    Text("Valid for 24 hours. Share it with your student.")
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                }

                Button(action: { Task { await generate() } }) {
                    Text(primaryTitle)
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            palette.accent.opacity(isGenerating ? 0.35 : 1),
                            in: RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                        )
                }
                .buttonStyle(.praccyPress(shadow: isGenerating ? .clear : palette.shadow, offset: 2))
                .disabled(isGenerating)

                if let errorMessage {
                    Text(errorMessage)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var primaryTitle: String {
        if isGenerating { return "Generating…" }
        return generatedCode == nil ? "Generate code" : "New code"
    }

    private func generate() async {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }
        do {
            generatedCode = try await backend.generateJoinCode(teacherDisplayName: teacherDisplayName)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var myStudentsCard: some View {
        SettingsSectionCard(eyebrow: "My students", palette: palette) {
            if links.isEmpty {
                Text("No students yet.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink45)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 14) {
                    ForEach(links) { link in
                        LinkRow(
                            name: link.studentDisplayName,
                            instrument: link.studentInstrument,
                            palette: palette,
                            onUnlink: { onRequestUnlink(link) }
                        )
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Empty") {
    TeacherLinksSection(links: [], palette: .violet) { _ in }
        .padding(22)
        .background(AccentPalette.violet.bg)
}
#endif
