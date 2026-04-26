import SwiftUI
import SwiftData
import AVFoundation

@main
struct PraccyApp: App {
    private let container: ModelContainer = PraccySchema.makeContainer()
    private let backend: any PraccyBackend
    private let queue: BackendOperationQueue

    init() {
        let backend = Self.makeBackend()
        self.backend = backend
        self.queue = BackendOperationQueue(backend: backend)
        Self.activateAudioSession()
        PraccyAppearance.install()
        wireUploadCompletionHandler()
        #if DEBUG
        // Must run before any view mounts: deleting a `TeacherLink` under a live
        // `PracticeTask.assignedBy` reference crashes the generated @Model getter.
        MainActor.assumeIsolated {
            Self.applyDebugLaunchArgs(in: container.mainContext)
        }
        #endif
    }

    /// Stamps `Recording.uploadedAt` locally when the queue reports a successful upload.
    private func wireUploadCompletionHandler() {
        let container = container
        Task {
            await queue.setRecordingUploadedHandler { recordingID, result in
                await MainActor.run {
                    let context = container.mainContext
                    let descriptor = FetchDescriptor<Recording>(
                        predicate: #Predicate { $0.id == recordingID }
                    )
                    guard let recording = try? context.fetch(descriptor).first else { return }
                    recording.uploadedAt = result.uploadedAt
                    try? context.save()
                }
            }
        }
    }

    /// Release: `CloudKitBackend`. DEBUG: `MockBackend` unless `-UseCloudKitBackend` is passed.
    private static func makeBackend() -> any PraccyBackend {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UseCloudKitBackend") {
            return CloudKitBackend()
        }
        return MockBackend()
        #else
        return CloudKitBackend()
        #endif
    }

    /// Warms the playback session at launch so the first metronome/tuner tap doesn't race `setActive(true)`.
    private static func activateAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(\.backend, backend)
                .environment(\.backendQueue, queue)
        }
        .modelContainer(container)
    }

    #if DEBUG
    /// Launch-arg dev aids:
    /// - `-ForceOnboarding` wipes link subtree + Keychain + `onboardingCompleted`; preserves profile.
    /// - `-SeedStudent` / `-SeedTeacher` wipes and re-seeds starter state.
    /// Handled in order so `-ForceOnboarding` + `-Seed*` together is predictable.
    @MainActor
    private static func applyDebugLaunchArgs(in context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ForceOnboarding") {
            applyForceOnboarding(in: context)
        }
        applyDebugSeedIfRequested(in: context)
    }

    @MainActor
    private static func applyForceOnboarding(in context: ModelContext) {
        // Don't delete `UserSettings`; `AppShell` depends on the singleton existing.
        deleteAll(PracticeTask.self, in: context)
        deleteAll(Recording.self, in: context)
        deleteAll(Goal.self, in: context)
        deleteAll(TeacherLink.self, in: context)
        deleteAll(StudentLink.self, in: context)
        KeychainStore.clear()
        let settings = UserSettings.current(in: context)
        settings.onboardingCompleted = false
        settings.email = nil
        try? context.save()
    }

    @MainActor
    private static func applyDebugSeedIfRequested(in context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        let wantsStudent = args.contains("-SeedStudent")
        let wantsTeacher = args.contains("-SeedTeacher")
        guard wantsStudent || wantsTeacher else { return }

        wipeAllModelData(in: context)

        if wantsStudent {
            SeedData.seedStudent(in: context)
        } else if wantsTeacher {
            SeedData.seedTeacher(in: context)
        }
        try? context.save()
    }

    @MainActor
    private static func wipeAllModelData(in context: ModelContext) {
        deleteAll(PracticeTask.self, in: context)
        deleteAll(Recording.self, in: context)
        deleteAll(Goal.self, in: context)
        deleteAll(TeacherLink.self, in: context)
        deleteAll(StudentLink.self, in: context)
        deleteAll(UserSettings.self, in: context)
        try? context.save()
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let rows = try? context.fetch(FetchDescriptor<T>()) else { return }
        for row in rows {
            context.delete(row)
        }
    }
    #endif
}
