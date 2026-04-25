import SwiftUI
import SwiftData
import UIKit

/// Student-role-only: code-entry card + My-teachers list. Unlink fires upward for a parent-owned alert.
struct StudentLinksSection: View {
    let links: [TeacherLink]
    let palette: AccentPalette
    let onRequestUnlink: (TeacherLink) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend

    @State private var code: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            connectCard
            myTeachersCard
        }
    }

    private var connectCard: some View {
        SettingsSectionCard(eyebrow: "Connect with a teacher", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("XXXXXX", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                    .keyboardType(.asciiCapable)
                    .font(PraccyFont.task)
                    .tracking(6)
                    .foregroundStyle(PraccyColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                            .fill(Color.white)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                            .strokeBorder(palette.accent.opacity(0.2), lineWidth: 1.5)
                    }
                    .disabled(isSubmitting)
                    .focused($codeFieldFocused)
                    .onChange(of: code) { _, newValue in
                        let filtered = newValue
                            .uppercased()
                            .filter { JoinCodeGenerator.alphabet.contains($0) }
                        let clipped = String(filtered.prefix(JoinCodeGenerator.codeLength))
                        if clipped != newValue { code = clipped }
                        if errorMessage != nil { errorMessage = nil }
                        if successMessage != nil { successMessage = nil }
                    }

                Button(action: { Task { await submit() } }) {
                    Text(isSubmitting ? "Connecting…" : "Connect")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            palette.accent.opacity(primaryEnabled ? 1 : 0.35),
                            in: RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                        )
                }
                .buttonStyle(.praccyPress(shadow: primaryEnabled ? palette.shadow : .clear, offset: 2))
                .disabled(!primaryEnabled)

                if let errorMessage {
                    Text(errorMessage)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(PraccyFont.meta)
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var primaryEnabled: Bool {
        !isSubmitting && JoinCodeGenerator.normalise(code) != nil
    }

    private func submit() async {
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let descriptor = try await backend.redeemJoinCode(code)
            let link = TeacherLink(
                teacherDisplayName: descriptor.teacherDisplayName,
                teacherInstrument: descriptor.teacherInstrument,
                remoteTeacherID: descriptor.remoteTeacherID,
                remoteLinkID: descriptor.remoteLinkID,
                linkedAt: descriptor.linkedAt,
                state: .active
            )
            modelContext.insert(link)
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            successMessage = "Linked with \(descriptor.teacherDisplayName)."
            code = ""
            codeFieldFocused = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var myTeachersCard: some View {
        SettingsSectionCard(eyebrow: "My teachers", palette: palette) {
            if links.isEmpty {
                Text("No teachers yet.")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink45)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 14) {
                    ForEach(links) { link in
                        LinkRow(
                            name: link.teacherDisplayName,
                            instrument: link.teacherInstrument,
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
    ScrollView {
        StudentLinksSection(links: [], palette: .violet) { _ in }
            .padding(22)
    }
    .background(AccentPalette.violet.bg)
}
#endif
