import AuthenticationServices
import SwiftUI
import SwiftData

/// Scene root. Owns onboarding↔main switching and the `UserSettings` singleton bootstrap.
/// Starts in `.initial` rendering only the bg so the handoff from `LaunchScreen.storyboard` is quiet.
struct AppShell: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend
    @Query private var settingsRows: [UserSettings]

    @State private var phase: AppPhase = .initial

    private var palette: AccentPalette { .violet }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            switch phase {
            case .initial:
                Color.clear
            case .onboarding:
                OnboardingFlow(onComplete: completeOnboarding)
            case .main:
                RootView()
            }
        }
        .task {
            bootstrapSettingsIfNeeded()
            await decideInitialPhase()
        }
        .onChange(of: settingsRows.first?.onboardingCompleted ?? false) { _, completed in
            // Sign-out from main resets `onboardingCompleted`; bounce so the user lands on sign-in.
            if !completed, phase == .main {
                phase = .onboarding
            }
        }
    }

    // MARK: - Bootstrap + transitions

    private func bootstrapSettingsIfNeeded() {
        guard settingsRows.isEmpty else { return }
        _ = UserSettings.current(in: modelContext)
        try? modelContext.save()
    }

    private func decideInitialPhase() async {
        guard phase == .initial else { return }
        let completed = settingsRows.first?.onboardingCompleted ?? false
        guard completed else {
            phase = .onboarding
            return
        }
        // Guard against a revoked Apple ID / signed-out iCloud since last launch; otherwise every
        // CloudKit call on main would throw `.iCloudUnavailable`.
        if await credentialIsStale() {
            softSignOut()
            phase = .onboarding
            return
        }
        await rehydrateBackendSession()
        phase = .main
    }

    /// In-memory backends (MockBackend) lose `signedInUser` across launches even though the
    /// Keychain credential survives. Replay sign-in so calls like `generateJoinCode` don't
    /// throw `.notSignedIn` until the user re-onboards.
    private func rehydrateBackendSession() async {
        guard let identifier = KeychainStore.load() else { return }
        if (try? await backend.currentUser()) != nil { return }
        let settings = settingsRows.first
        _ = try? await backend.signIn(
            credentialIdentifier: identifier,
            displayName: settings?.displayName,
            email: settings?.email
        )
    }

    private func credentialIsStale() async -> Bool {
        guard let identifier = KeychainStore.load() else {
            return false
        }
        #if DEBUG
        // Apple's provider always reports the dev fixture as `.notFound`; skip the check.
        if identifier == AppleSignInService.Summary.devFixture.userIdentifier {
            return false
        }
        #endif
        let state = await AppleSignInService.credentialState(forUserIdentifier: identifier)
        switch state {
        case .authorized, .transferred:
            return false
        case .revoked, .notFound:
            return true
        @unknown default:
            return false
        }
    }

    /// Wipes link subtree + identity metadata locally when backend tear-down isn't reachable.
    private func softSignOut() {
        wipeLinkedData(PracticeTask.self)
        wipeLinkedData(TeacherLink.self)
        wipeLinkedData(StudentLink.self)
        wipeLinkedData(Goal.self)
        KeychainStore.clear()
        if let settings = settingsRows.first {
            settings.email = nil
            settings.onboardingCompleted = false
        }
        try? modelContext.save()
    }

    private func wipeLinkedData<T: PersistentModel>(_ type: T.Type) {
        guard let rows = try? modelContext.fetch(FetchDescriptor<T>()) else { return }
        for row in rows {
            modelContext.delete(row)
        }
    }

    private func completeOnboarding() {
        guard let settings = settingsRows.first else { return }
        settings.onboardingCompleted = true
        try? modelContext.save()
        phase = .main
    }
}

enum AppPhase: Equatable {
    case initial
    case onboarding
    case main
}

#if DEBUG
#Preview("Fresh - onboarding") {
    let container = PraccySchema.makeContainer(inMemory: true)
    return AppShell()
        .modelContainer(container)
}

#Preview("Seeded student - main") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedStudent(in: container.mainContext)
    return AppShell()
        .modelContainer(container)
}

#Preview("Seeded teacher - main") {
    let container = PraccySchema.makeContainer(inMemory: true)
    SeedData.seedTeacher(in: container.mainContext)
    return AppShell()
        .modelContainer(container)
}
#endif
