import SwiftUI
import SwiftData

/// Settings sheet presented from the header cog. Owns every alert; leaf sections fire intents up.
struct SettingsSheet: View {
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsRows: [UserSettings]
    @Query private var teacherLinks: [TeacherLink]
    @Query private var studentLinks: [StudentLink]

    @State private var pendingUnlinkTeacher: TeacherLink?
    @State private var pendingUnlinkStudent: StudentLink?
    @State private var showingAboutAlert = false

    private var settings: UserSettings {
        settingsRows.first ?? UserSettings.current(in: modelContext)
    }

    private var activeTeacherLinks: [TeacherLink] {
        teacherLinks
            .filter { $0.state == .active }
            .sorted { $0.linkedAt > $1.linkedAt }
    }

    private var activeStudentLinks: [StudentLink] {
        studentLinks
            .filter { $0.state == .active }
            .sorted { ($0.lastSeenAt ?? $0.linkedAt) > ($1.lastSeenAt ?? $1.linkedAt) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PraccySheetHeader(title: "Settings", palette: palette) { dismiss() }
            sheetScroll
        }
        .background(palette.bg.ignoresSafeArea())
        .modifier(
            SettingsAlerts(
                pendingUnlinkTeacher: $pendingUnlinkTeacher,
                pendingUnlinkStudent: $pendingUnlinkStudent,
                showingAboutAlert: $showingAboutAlert,
                onCommitUnlinkTeacher: commitUnlink(teacher:),
                onCommitUnlinkStudent: commitUnlink(student:)
            )
        )
    }

    @ViewBuilder
    private var sheetScroll: some View {
        ScrollView {
            VStack(spacing: 28) {
                AccountSection(palette: palette)

                linksSection

                if settings.role == .student {
                    InstrumentSection(
                        name: settings.instrument ?? "",
                        selectedIcon: settings.instrumentIcon,
                        palette: palette,
                        onNameChange: updateInstrumentName,
                        onIconChange: updateInstrumentIcon
                    )
                }

                AboutSection(palette: palette) {
                    showingAboutAlert = true
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 48)
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        if settings.role == .student {
            StudentLinksSection(
                links: activeTeacherLinks,
                palette: palette,
                onRequestUnlink: { pendingUnlinkTeacher = $0 }
            )
        } else {
            TeacherLinksSection(
                links: activeStudentLinks,
                palette: palette,
                onRequestUnlink: { pendingUnlinkStudent = $0 }
            )
        }
    }

    // MARK: - Commits

    private func commitUnlink(teacher link: TeacherLink) {
        link.state = .severed
        try? modelContext.save()
        pendingUnlinkTeacher = nil
    }

    private func commitUnlink(student link: StudentLink) {
        link.state = .severed
        try? modelContext.save()
        pendingUnlinkStudent = nil
    }

    private func updateInstrumentName(_ newName: String) {
        settings.instrument = newName.isEmpty ? nil : newName
        try? modelContext.save()
    }

    private func updateInstrumentIcon(_ symbol: String) {
        settings.instrumentIcon = symbol
        try? modelContext.save()
    }
}

// MARK: - SettingsAlerts
//
// Chaining four `.alert` modifiers on the ScrollView directly blows past
// SwiftUI's type checker budget. Extracting them into a single
// `ViewModifier` keeps each alert's call site small enough to type-check
// and localises the alert-binding boilerplate here.

private struct SettingsAlerts: ViewModifier {
    @Binding var pendingUnlinkTeacher: TeacherLink?
    @Binding var pendingUnlinkStudent: StudentLink?
    @Binding var showingAboutAlert: Bool

    let onCommitUnlinkTeacher: (TeacherLink) -> Void
    let onCommitUnlinkStudent: (StudentLink) -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                "Unlink teacher?",
                isPresented: isPresented($pendingUnlinkTeacher),
                presenting: pendingUnlinkTeacher,
                actions: { link in
                    Button("Unlink", role: .destructive) { onCommitUnlinkTeacher(link) }
                    Button("Cancel", role: .cancel) { pendingUnlinkTeacher = nil }
                },
                message: { link in
                    Text("Unlink from \(link.teacherDisplayName)? Tasks they've assigned will remain on your calendar.")
                }
            )
            .alert(
                "Unlink student?",
                isPresented: isPresented($pendingUnlinkStudent),
                presenting: pendingUnlinkStudent,
                actions: { link in
                    Button("Unlink", role: .destructive) { onCommitUnlinkStudent(link) }
                    Button("Cancel", role: .cancel) { pendingUnlinkStudent = nil }
                },
                message: { link in
                    Text("Unlink \(link.studentDisplayName) from your roster? You can re-invite them later.")
                }
            )
            .alert(
                "Coming at launch.",
                isPresented: $showingAboutAlert,
                actions: {
                    Button("OK", role: .cancel) { }
                }
            )
    }

    private func isPresented<T>(_ source: Binding<T?>) -> Binding<Bool> {
        Binding(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }
}

#if DEBUG
#Preview("Student - seeded") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return SettingsSheet(palette: .violet)
        .modelContainer(container)
}

#Preview("Teacher - seeded") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    return SettingsSheet(palette: .violet)
        .modelContainer(container)
}

#Preview("Fresh student") {
    SettingsSheet(palette: .violet)
        .modelContainer(PraccySchema.makeContainer(inMemory: true))
}
#endif
