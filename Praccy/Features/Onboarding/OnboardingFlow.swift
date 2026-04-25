import SwiftUI
import SwiftData

/// First-launch flow. State persists on `UserSettings` per step, so a kill-before-complete
/// resumes with role/name/instrument intact (step cursor resets). `AppShell` flips the gate when done.
struct OnboardingFlow: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backend) private var backend
    @Query private var settingsRows: [UserSettings]

    @State private var step: OnboardingStep = .welcome
    @State private var isReversing: Bool = false

    // Link step state (student branch only): owned here so the footer CTA can drive the action.
    @State private var linkCode: String = ""
    @State private var linkError: String?
    @State private var linkIsSubmitting: Bool = false

    private var settings: UserSettings {
        settingsRows.first ?? UserSettings.current(in: modelContext)
    }

    private var palette: AccentPalette { .violet }

    /// The ordered subset of steps shown for the current role. Teachers skip Instrument (they may
    /// teach multiple) and Link (they generate codes from the Students tab empty state instead).
    private var activeSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [.welcome, .signIn, .rolePicker, .displayName]
        if settings.role == .student {
            steps.append(.instrument)
            steps.append(.link)
        }
        steps.append(.done)
        return steps
    }

    private var currentStepIndex: Int {
        activeSteps.firstIndex(of: step) ?? 0
    }

    private func nextStep(after current: OnboardingStep) -> OnboardingStep? {
        guard let idx = activeSteps.firstIndex(of: current), idx + 1 < activeSteps.count else {
            return nil
        }
        return activeSteps[idx + 1]
    }

    private func previousStep(before current: OnboardingStep) -> OnboardingStep? {
        // Welcome / Done never show a back arrow.
        if current == .welcome || current == .done { return nil }
        guard let idx = activeSteps.firstIndex(of: current), idx > 0 else {
            return nil
        }
        return activeSteps[idx - 1]
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    ScrollView {
                        stepContent
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id(step)
                    .transition(stepTransition)
                }

                footer
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let previous = previousStep(before: step) {
                Button(action: { advance(to: previous) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(PraccyColor.ink)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: Circle())
                }
                .buttonStyle(.praccyPress(shadow: palette.shadow.opacity(0.25), offset: 2))
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            OnboardingProgressDots(current: currentStepIndex, total: activeSteps.count, palette: palette)
                .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    // MARK: - Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStep(palette: palette)

        case .signIn:
            SignInStep(
                palette: palette,
                isSignedIn: KeychainStore.load() != nil,
                currentDisplayName: settings.displayName,
                currentEmail: settings.email,
                onSignIn: handleSignIn
            )

        case .rolePicker:
            RolePickerStep(
                palette: palette,
                role: settings.role,
                onRoleChange: updateRole
            )

        case .displayName:
            DisplayNameStep(
                palette: palette,
                initialName: settings.displayName ?? "",
                onNameChange: updateDisplayName,
                onSubmit: { advanceToNext() }
            )

        case .instrument:
            InstrumentStep(
                palette: palette,
                name: settings.instrument ?? "",
                selectedIcon: settings.instrumentIcon,
                onNameChange: updateInstrumentName,
                onIconChange: updateInstrumentIcon
            )

        case .link:
            LinkStep(
                palette: palette,
                code: $linkCode,
                errorMessage: linkError,
                isSubmitting: linkIsSubmitting
            )

        case .done:
            DoneStep(palette: palette, role: settings.role)
        }
    }

    // MARK: - Footer (persistent CTAs)

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(PraccyFont.task)
                    .tracking(-0.2)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        palette.accent.opacity(primaryEnabled ? 1.0 : 0.35),
                        in: RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge)
                    )
                    .contentTransition(.identity)
            }
            .buttonStyle(.praccyPress(shadow: primaryEnabled ? palette.shadow : .clear))
            .disabled(!primaryEnabled)

            if let secondary = secondaryAction {
                Button(action: secondary.action) {
                    Text(secondary.title)
                        .font(PraccyFont.meta)
                        .foregroundStyle(PraccyColor.ink60)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentTransition(.identity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: - CTA derivation

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Get started"
        case .signIn: return "Continue"
        case .rolePicker, .displayName, .instrument: return "Next"
        case .link:
            return linkIsSubmitting ? "Connecting…" : "Connect"
        case .done: return "Let's go!"
        }
    }

    private var primaryEnabled: Bool {
        switch step {
        case .signIn:
            // Continue only after Apple Sign-In landed a user identifier.
            return KeychainStore.load() != nil
        case .displayName:
            return !(settings.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case .link:
            if linkIsSubmitting { return false }
            return JoinCodeGenerator.normalise(linkCode) != nil
        default:
            return true
        }
    }

    private func primaryAction() {
        switch step {
        case .link:
            Task { await submitJoinCode() }
        case .done:
            onComplete()
        default:
            advanceToNext()
        }
    }

    private func advanceToNext() {
        if let next = nextStep(after: step) {
            advance(to: next)
        }
    }

    /// Only the link step exposes a secondary "skip" action.
    private var secondaryAction: (title: String, action: () -> Void)? {
        switch step {
        case .link:
            return ("I'll do this later", advanceToNext)
        default:
            return nil
        }
    }

    // MARK: - Transitions

    /// `advance` sets `isReversing` first then defers the `step` mutation one tick,
    /// so the outgoing view re-renders with the correct edge before its identity swaps.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isReversing ? .leading : .trailing),
            removal: .move(edge: isReversing ? .trailing : .leading)
        )
    }

    private func advance(to next: OnboardingStep) {
        let nextIdx = activeSteps.firstIndex(of: next) ?? 0
        isReversing = nextIdx < currentStepIndex
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.28)) {
                step = next
            }
        }
    }

    // MARK: - Commits

    /// Stashes credential + display metadata, tells the backend, auto-advances to role picker.
    private func handleSignIn(_ summary: AppleSignInService.Summary) async throws {
        KeychainStore.save(summary.userIdentifier)
        if let email = summary.email, !email.isEmpty {
            settings.email = email
        }
        if settings.displayName == nil || settings.displayName?.isEmpty == true,
           let name = summary.displayName, !name.isEmpty {
            settings.displayName = name
        }
        try? modelContext.save()

        _ = try await backend.signIn(
            credentialIdentifier: summary.userIdentifier,
            displayName: summary.displayName ?? settings.displayName,
            email: summary.email ?? settings.email
        )

        advanceToNext()
    }

    private func updateRole(_ role: UserRole) {
        settings.role = role
        try? modelContext.save()
    }

    private func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.displayName = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
    }

    private func updateInstrumentName(_ name: String) {
        settings.instrument = name.isEmpty ? nil : name
        try? modelContext.save()
    }

    private func updateInstrumentIcon(_ symbol: String) {
        settings.instrumentIcon = symbol
        try? modelContext.save()
    }

    // MARK: - Link step actions

    /// Student-side redeem. Backend descriptor is authoritative for remote identity.
    private func submitJoinCode() async {
        linkError = nil
        linkIsSubmitting = true
        defer { linkIsSubmitting = false }

        do {
            let descriptor = try await backend.redeemJoinCode(linkCode)
            let link = TeacherLink(
                teacherDisplayName: descriptor.teacherDisplayName,
                teacherInstrument: descriptor.teacherInstrument,
                remoteTeacherID: descriptor.remoteTeacherID,
                remoteLinkID: descriptor.remoteLinkID,
                linkedAt: descriptor.linkedAt,
                state: .active
            )
            modelContext.insert(link)
            try? modelContext.save()
            advanceToNext()
        } catch {
            linkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Step enum

enum OnboardingStep: Equatable {
    case welcome
    case signIn
    case rolePicker
    case displayName
    case instrument
    case link
    case done
}

#if DEBUG
#Preview("Fresh - student default") {
    let container = PraccySchema.makeContainer(inMemory: true)
    return OnboardingFlow(onComplete: {})
        .modelContainer(container)
}
#endif
