import SwiftUI
import SwiftData

/// Roster row body. Active = tappable (parent wraps in `NavigationLink`); pending shows a Cancel control.
struct StudentRosterRow: View {
    let link: StudentLink
    let palette: AccentPalette
    let activeTaskCount: Int
    let onCancelPending: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var avatarDiameter: CGFloat = 44

    init(
        link: StudentLink,
        palette: AccentPalette,
        activeTaskCount: Int,
        onCancelPending: (() -> Void)? = nil
    ) {
        self.link = link
        self.palette = palette
        self.activeTaskCount = activeTaskCount
        self.onCancelPending = onCancelPending
    }

    private var initial: String {
        let trimmed = link.studentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            avatar
                .accessibilityHidden(true)
            identity
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(identityAccessibilityLabel)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow.opacity(0.22), offset: 3)
    }

    private var identityAccessibilityLabel: String {
        var parts: [String] = [link.studentDisplayName]
        if let instrument = link.studentInstrument?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instrument.isEmpty {
            parts.append(instrument)
        }
        switch link.state {
        case .active:
            parts.append(activeTaskCount == 0
                ? "all done"
                : "\(activeTaskCount) task\(activeTaskCount == 1 ? "" : "s") to do")
        case .pending:
            parts.append("waiting to join")
        case .severed:
            break
        }
        return parts.joined(separator: ", ")
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(palette.surface)
            Text(initial)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(palette.accent)
        }
        .frame(width: avatarDiameter, height: avatarDiameter)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(link.studentDisplayName)
                .font(PraccyFont.task)
                .tracking(-0.2)
                .foregroundStyle(PraccyColor.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(secondaryLine)
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var secondaryLine: String {
        var parts: [String] = []
        if let instrument = link.studentInstrument?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instrument.isEmpty {
            parts.append(instrument)
        }
        switch link.state {
        case .active:
            parts.append(activeTaskCount == 0 ? "All done" : "\(activeTaskCount) to do")
        case .pending:
            parts.append("Waiting to join")
        case .severed:
            break
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var trailing: some View {
        if link.state == .active {
            PraccyIcon.view(for: .chevronRight, tint: PraccyColor.ink45, size: 14)
        } else if link.state == .pending, let onCancelPending {
            Button(action: onCancelPending) {
                Text("Cancel")
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.ink60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: PraccyRadius.chip)
                            .strokeBorder(PraccyColor.ink10, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.praccyPress(offset: 2))
            .fixedSize()
            .accessibilityLabel("Cancel pending invite for \(link.studentDisplayName)")
        }
    }

}

#if DEBUG
#Preview("Active + pending") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    let links = container.mainContext.activeRoster()

    return VStack(spacing: 14) {
        ForEach(links) { link in
            StudentRosterRow(
                link: link,
                palette: .violet,
                activeTaskCount: container.mainContext.assignedTaskCount(for: link),
                onCancelPending: link.state == .pending ? {} : nil
            )
        }
    }
    .padding(22)
    .background(AccentPalette.violet.bg)
    .modelContainer(container)
}
#endif
