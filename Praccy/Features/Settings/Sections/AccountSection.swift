import SwiftUI
import SwiftData

/// Account controls. Sign out wipes link subtree + Keychain only; delete-account additionally
/// wipes prefs, recording files, and unlinks every active student on teacher accounts.
struct AccountSection: View {
    let palette: AccentPalette

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend
    @Query private var settingsRows: [UserSettings]

    @State private var confirmingSignOut: Bool = false
    @State private var isSigningOut: Bool = false
    @State private var confirmingDeleteAccount: Bool = false
    @State private var isDeletingAccount: Bool = false

    private var settings: UserSettings? {
        settingsRows.first
    }

    private var emailValue: String {
        if let email = settings?.email, !email.isEmpty {
            return email
        }
        if KeychainStore.load() != nil {
            return "Signed in with Apple"
        }
        return "Not signed in"
    }

    private var isBusy: Bool { isSigningOut || isDeletingAccount }

    private var canSignOut: Bool {
        KeychainStore.load() != nil && !isBusy
    }

    private var canDeleteAccount: Bool {
        // Stays available without a Keychain identity so half-onboarded state can still wipe.
        !isBusy && hasAnyLocalState
    }

    private var hasAnyLocalState: Bool {
        if KeychainStore.load() != nil { return true }
        if let s = settings, s.displayName != nil || s.instrument != nil || s.email != nil {
            return true
        }
        return false
    }

    var body: some View {
        SettingsSectionCard(eyebrow: "Account", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Email", trailing: .value(emailValue))

                Divider().overlay(palette.accent.opacity(0.12))

                Button { confirmingSignOut = true } label: {
                    Text(isSigningOut ? "Signing out…" : "Sign out")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(PraccyColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSignOut)
                .opacity(canSignOut ? 1 : 0.35)

                Divider().overlay(palette.accent.opacity(0.12))

                Button { confirmingDeleteAccount = true } label: {
                    Text(isDeletingAccount ? "Deleting…" : "Delete account")
                        .font(PraccyFont.task)
                        .tracking(-0.2)
                        .foregroundStyle(PraccyColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteAccount)
                .opacity(canDeleteAccount ? 1 : 0.35)
            }
        }
        .alert(
            "Sign out of Praccy?",
            isPresented: $confirmingSignOut,
            actions: {
                Button("Sign out", role: .destructive) {
                    Task { await performSignOut() }
                }
                Button("Cancel", role: .cancel) { }
            },
            message: {
                Text("Your teachers, students, tasks, and recordings will be removed from this device. Your role and instrument settings will be kept.")
            }
        )
        .alert(
            "Delete your Praccy account?",
            isPresented: $confirmingDeleteAccount,
            actions: {
                Button("Delete", role: .destructive) {
                    Task { await performDeleteAccount() }
                }
                Button("Cancel", role: .cancel) { }
            },
            message: {
                Text("This permanently removes your name, role, instrument, teachers, students, tasks, goals, and recordings from this device. This cannot be undone.")
            }
        )
    }

    // MARK: - Sign out

    private func performSignOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        try? await backend.signOut()

        // Preserve UserSettings; only the link subtree + identity metadata wipes.
        await MainActor.run {
            wipeLocalLinkedData()
            KeychainStore.clear()
            if let settings = settingsRows.first {
                settings.email = nil
                settings.onboardingCompleted = false
            }
            try? modelContext.save()
        }
    }

    // MARK: - Delete account

    private func performDeleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        // Best-effort per-link unlinks; a stale CloudKit row mustn't block the wipe.
        if settings?.role == .teacher {
            let allLinks = (try? modelContext.fetch(FetchDescriptor<StudentLink>())) ?? []
            for link in allLinks where link.state == .active {
                let remoteID = link.remoteLinkID ?? link.remoteStudentID
                _ = try? await backend.unlink(remoteLinkID: remoteID)
            }
        }

        try? await backend.signOut()

        await MainActor.run {
            wipeLocalLinkedData()
            wipeRecordingFiles()
            resetUserSettings()
            KeychainStore.clear()
            try? modelContext.save()
        }
    }

    /// SwiftData cascade only drops `Recording` rows; the `.m4a` files on disk need manual cleanup.
    private func wipeRecordingFiles() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let recordingsDir = docs.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.removeItem(at: recordingsDir)
    }

    /// Resets to fresh-install defaults; mirrors `UserSettings` init.
    private func resetUserSettings() {
        guard let settings = settingsRows.first else { return }
        settings.displayName = nil
        settings.instrument = nil
        settings.instrumentIcon = nil
        settings.role = .student
        settings.onboardingCompleted = false
        settings.lastUsedBPM = nil
        settings.email = nil
        settings.lastUsedTunerNote = nil
        settings.lastUsedTunerOctave = nil
        settings.lastUsedReferenceFrequency = nil
        settings.bestStreak = 0
    }

    // MARK: - Shared wipe

    private func wipeLocalLinkedData() {
        // Task delete cascades `Recording` via the inverse rule.
        delete(PracticeTask.self)
        delete(TeacherLink.self)
        delete(StudentLink.self)
        delete(Goal.self)
    }

    private func delete<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        for row in rows {
            modelContext.delete(row)
        }
    }
}

#if DEBUG
#Preview {
    AccountSection(palette: .violet)
        .padding(22)
        .background(AccentPalette.violet.bg)
        .modelContainer(PraccySchema.makeContainer(inMemory: true))
}
#endif
