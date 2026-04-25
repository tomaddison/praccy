import SwiftUI

/// Role picker. First-time choice during onboarding; roles aren't switchable in Settings,
/// so make it explicit here.
struct RolePickerStep: View {
    let palette: AccentPalette
    let role: UserRole
    let onRoleChange: (UserRole) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Pick your role.")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Choose carefully. You can't change this later.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)

            HStack(spacing: 10) {
                roleChip(.student, label: "Student")
                roleChip(.teacher, label: "Teacher")
            }
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func roleChip(_ target: UserRole, label: String) -> some View {
        let isActive = role == target
        Button {
            guard !isActive else { return }
            onRoleChange(target)
        } label: {
            Text(label)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(isActive ? palette.onAccent : PraccyColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: PraccyRadius.pill)
                        .fill(isActive ? palette.accent : palette.surface)
                )
        }
        .buttonStyle(.praccyPress(offset: 2))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#if DEBUG
#Preview("Student") {
    RolePickerStep(
        palette: .violet,
        role: .student,
        onRoleChange: { _ in }
    )
}

#Preview("Teacher") {
    RolePickerStep(
        palette: .violet,
        role: .teacher,
        onRoleChange: { _ in }
    )
}
#endif
