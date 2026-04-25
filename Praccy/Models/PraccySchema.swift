import Foundation
import SwiftData

/// Central schema definition. Every `@Model` type is listed in `models` exactly once.
enum PraccySchema {
    static let models: [any PersistentModel.Type] = [
        PracticeTask.self,
        Goal.self,
        Recording.self,
        TeacherLink.self,
        StudentLink.self,
        UserSettings.self,
    ]

    /// Builds a local-only `ModelContainer`. `inMemory` is for previews/tests.
    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(models)
        // `.none` opts out of SwiftData's CloudKit mirroring. Sync is owned by `CloudKitBackend`;
        // letting SwiftData pick up the app's iCloud entitlement throws at launch when the
        // container isn't provisioned (Personal Team, pre-paid-Developer-Program).
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create Praccy ModelContainer: \(error)")
        }
    }
}
