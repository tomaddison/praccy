import Foundation
import SwiftData

/// Singleton settings row. Read/write via `UserSettings.current(in:)`.
@Model
final class UserSettings {
    var displayName: String?
    var instrument: String?
    /// SF Symbol name from `InstrumentIconOptions`. Additive to the free-text `instrument`.
    var instrumentIcon: String?
    var role: UserRole
    var onboardingCompleted: Bool
    var lastUsedBPM: Int?

    /// Highest `currentStreak` ever observed. `0` = no best yet. Defaulted so lightweight migration works.
    var bestStreak: Int = 0

    /// Apple credential email (possibly a private relay). Identity proper lives in `KeychainStore`
    /// so it survives a local SwiftData wipe; email stays here as display metadata.
    var email: String?

    var lastUsedTunerNote: String?
    var lastUsedTunerOctave: Int?
    var lastUsedReferenceFrequency: Double?

    init(
        displayName: String? = nil,
        instrument: String? = nil,
        instrumentIcon: String? = nil,
        role: UserRole = .student,
        onboardingCompleted: Bool = false,
        lastUsedBPM: Int? = nil,
        email: String? = nil,
        lastUsedTunerNote: String? = nil,
        lastUsedTunerOctave: Int? = nil,
        lastUsedReferenceFrequency: Double? = nil,
        bestStreak: Int = 0
    ) {
        self.displayName = displayName
        self.instrument = instrument
        self.instrumentIcon = instrumentIcon
        self.role = role
        self.onboardingCompleted = onboardingCompleted
        self.lastUsedBPM = lastUsedBPM
        self.email = email
        self.lastUsedTunerNote = lastUsedTunerNote
        self.lastUsedTunerOctave = lastUsedTunerOctave
        self.lastUsedReferenceFrequency = lastUsedReferenceFrequency
        self.bestStreak = bestStreak
    }

    /// Fetches the row, inserting a default on fresh install. Caller saves the context after mutating.
    @MainActor
    static func current(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = UserSettings()
        context.insert(fresh)
        return fresh
    }
}
