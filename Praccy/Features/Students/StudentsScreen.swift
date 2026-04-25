import SwiftUI
import SwiftData

/// Teacher's roster surface. Active rows push into `StudentDetailScreen`; pending rows show a Cancel pill.
struct StudentsScreen: View {
    let palette: AccentPalette
    @Binding var path: [StudentLink]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend

    @Query(sort: \StudentLink.linkedAt, order: .reverse)
    private var allLinks: [StudentLink]

    @State private var showAddStudent: Bool = false
    @State private var pendingCancel: StudentLink?
    @State private var cancelError: String?

    private var roster: [StudentLink] {
        allLinks.filter { $0.state != .severed }.sorted { a, b in
            if a.state != b.state {
                return a.state == .active && b.state == .pending
            }
            return (a.lastSeenAt ?? a.linkedAt) > (b.lastSeenAt ?? b.linkedAt)
        }
    }

    private var activeLinks: [StudentLink] {
        roster.filter { $0.state == .active }
    }

    private var pendingLinks: [StudentLink] {
        roster.filter { $0.state == .pending }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack(path: $path) {
                content
                    .background(palette.bg.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: StudentLink.self) { link in
                        StudentDetailScreen(link: link, palette: palette)
                    }
            }

            if path.isEmpty && !roster.isEmpty {
                addStudentFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showAddStudent) {
            AddStudentSheet(palette: palette)
        }
        .alert(
            "Cancel invite?",
            isPresented: Binding(
                get: { pendingCancel != nil },
                set: { if !$0 { pendingCancel = nil } }
            ),
            presenting: pendingCancel
        ) { link in
            Button("Cancel invite", role: .destructive) {
                Task { await cancelPending(link) }
            }
            Button("Keep", role: .cancel) { pendingCancel = nil }
        } message: { link in
            Text("\(link.studentDisplayName) will need a new code to join.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if roster.isEmpty {
            StudentEmptyState(
                headline: "No students yet",
                subtitle: "Invite one with a join code.",
                ctaTitle: "Add your first student",
                palette: palette,
                onCTA: { showAddStudent = true }
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !activeLinks.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(activeLinks) { link in
                                rowFor(link)
                            }
                        }
                    }
                    if !pendingLinks.isEmpty {
                        section(title: "Waiting to join", links: pendingLinks)
                    }
                    if let cancelError {
                        Text(cancelError)
                            .font(PraccyFont.meta)
                            .foregroundStyle(PraccyColor.warning)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 96)
            }
        }
    }

    private var addStudentFAB: some View {
        Button {
            showAddStudent = true
        } label: {
            ZStack {
                Circle().fill(palette.accent)
                PraccyIcon.view(for: .plus, tint: palette.onAccent, size: 20)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.praccyPress(shadow: palette.shadow))
        .accessibilityLabel("Add student")
    }

    @ViewBuilder
    private func section(title: String, links: [StudentLink]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PraccyFont.meta)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(PraccyColor.ink60)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(links) { link in
                    rowFor(link)
                }
            }
        }
    }

    @ViewBuilder
    private func rowFor(_ link: StudentLink) -> some View {
        let count = modelContext.assignedTaskCount(for: link)
        if link.state == .active {
            NavigationLink(value: link) {
                StudentRosterRow(
                    link: link,
                    palette: palette,
                    activeTaskCount: count
                )
            }
            .buttonStyle(.plain)
        } else {
            StudentRosterRow(
                link: link,
                palette: palette,
                activeTaskCount: count,
                onCancelPending: { pendingCancel = link }
            )
        }
    }

    private func cancelPending(_ link: StudentLink) async {
        cancelError = nil
        pendingCancel = nil
        do {
            try await backend.unlink(remoteLinkID: link.remoteLinkID ?? link.remoteStudentID)
            link.state = .severed
            try? modelContext.save()
        } catch {
            cancelError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("Seeded teacher") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    return StudentsScreen(palette: .violet, path: .constant([]))
        .modelContainer(container)
        .environment(\.backend, MockBackend(seed: .signedInTeacher))
}

#Preview("Empty roster") {
    let container = PraccySchema.makeContainer(inMemory: true)
    return StudentsScreen(palette: .violet, path: .constant([]))
        .modelContainer(container)
        .environment(\.backend, MockBackend(seed: .signedInTeacher))
}
#endif
