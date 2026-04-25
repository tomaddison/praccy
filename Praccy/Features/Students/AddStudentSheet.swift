import SwiftUI
import SwiftData

/// Generates a 6-char join code. Codes live 24 hours; pending roster rows appear via reconcile.
struct AddStudentSheet: View {
    let palette: AccentPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.backend) private var backend
    @Query private var settingsRows: [UserSettings]

    @State private var code: JoinCode?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?

    private var teacherDisplayName: String {
        let name = settingsRows.first?.displayName ?? ""
        return name.isEmpty ? "Teacher" : name
    }

    var body: some View {
        VStack(spacing: 0) {
            PraccySheetHeader(title: "Add student", palette: palette) { dismiss() }
            ScrollView {
                VStack(spacing: 26) {
                    header

                    if let code {
                        codeDisplay(code)
                        instructions(code: code.code)
                    } else {
                        placeholder
                    }

                    primaryButton

                    if let errorMessage {
                        Text(errorMessage)
                            .font(PraccyFont.meta)
                            .foregroundStyle(PraccyColor.warning)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.bg.ignoresSafeArea())
        .task { if code == nil { await generate() } }
    }

    private var header: some View {
        VStack(spacing: 10) {
            PraccyMascot(size: 110, mood: .happy, accent: palette.accent)
            Text("Invite a student")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
        }
        .padding(.top, 10)
    }

    private func codeDisplay(_ code: JoinCode) -> some View {
        VStack(spacing: 8) {
            Text(code.code)
                .font(PraccyFont.display)
                .tracking(8)
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.card)
                        .fill(Color.white)
                )
                .praccySolidShadow(color: palette.shadow.opacity(0.25), offset: 4)
                .accessibilityLabel("Code: \(code.code.map { String($0) }.joined(separator: " "))")

            Text("Valid for 24 hours.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
        }
    }

    private func instructions(code: String) -> some View {
        VStack(spacing: 12) {
            Text("Ask your student to enter this code in Settings → Connect with a teacher.")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            ShareLink(item: shareMessage(code: code)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                            .strokeBorder(palette.accent, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.praccyPress(offset: 2))
        }
    }

    private var placeholder: some View {
        Text(isGenerating ? "Making a code…" : "Tap below to make a code.")
            .font(PraccyFont.meta)
            .foregroundStyle(PraccyColor.ink60)
            .padding(.vertical, 40)
    }

    private var primaryButton: some View {
        Button(action: { Task { await generate() } }) {
            Text(code == nil ? "Make code" : "New code")
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    palette.accent.opacity(isGenerating ? 0.4 : 1),
                    in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                )
        }
        .buttonStyle(.praccyPress(shadow: isGenerating ? .clear : palette.shadow))
        .disabled(isGenerating)
    }

    private func shareMessage(code: String) -> String {
        "Join my Praccy roster with code \(code). Open Praccy, go to Settings → Connect with a teacher, and enter it there."
    }

    private func generate() async {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }
        do {
            code = try await backend.generateJoinCode(teacherDisplayName: teacherDisplayName)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("Add student") {
    AddStudentSheet(palette: .violet)
        .environment(\.backend, MockBackend(seed: .signedInTeacher))
}
#endif
