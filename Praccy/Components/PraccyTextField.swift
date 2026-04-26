import SwiftUI

/// Standard composer text field. Return triggers `onSubmit` (no `axis: .vertical`).
struct PraccyTextField<Field: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    let field: Field
    var focus: FocusState<Field?>.Binding
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(PraccyColor.ink45)
        )
        .font(PraccyFont.task)
        .tracking(-0.2)
        .foregroundStyle(PraccyColor.ink)
        .focused(focus, equals: field)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PraccyRadius.buttonSmall)
                .fill(PraccyColor.ink05)
        )
    }
}
