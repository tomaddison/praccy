import AuthenticationServices
import SwiftUI

/// Sign in with Apple step. Throws from `onSignIn` surface as inline errors.
struct SignInStep: View {
    let palette: AccentPalette
    /// Driven by `KeychainStore.load() != nil`; name/email persist across sign-out as device prefs.
    let isSignedIn: Bool
    let currentDisplayName: String?
    let currentEmail: String?
    let onSignIn: @MainActor (AppleSignInService.Summary) async throws -> Void

    @State private var inlineError: String?
    @State private var isWorking: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign in to Praccy.")
                .font(PraccyFont.title)
                .tracking(-0.6)
                .foregroundStyle(PraccyColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Praccy uses Apple ID to keep you in sync across devices and to link you with your teacher or students.")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .fixedSize(horizontal: false, vertical: true)

            if isSignedIn {
                signedInCard
                    .padding(.top, 8)
            } else {
                signInButton
                    .padding(.top, 8)
                #if DEBUG
                devSignInButton
                #endif
            }

            if let inlineError {
                Text(inlineError)
                    .font(PraccyFont.meta)
                    .foregroundStyle(PraccyColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Sign-in button

    private var signInButton: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: handleCompletion
        )
        .signInWithAppleButtonStyle(.black)
        .frame(minHeight: 56)
        .clipShape(RoundedRectangle(cornerRadius: PraccyRadius.buttonLarge))
        .praccySolidShadow(color: palette.shadow.opacity(0.35), offset: 3)
        .opacity(isWorking ? 0.5 : 1)
        .disabled(isWorking)
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        inlineError = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                inlineError = "Unexpected sign-in response. Try again."
                return
            }
            let summary = AppleSignInService.summarise(credential)
            isWorking = true
            Task { @MainActor in
                defer { isWorking = false }
                do {
                    try await onSignIn(summary)
                } catch {
                    inlineError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        case .failure(let error):
            // Swallow `.canceled` and `.unknown` (Simulator dismissal path); no useful message.
            if let asError = error as? ASAuthorizationError,
               asError.code == .canceled || asError.code == .unknown {
                return
            }
            inlineError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Dev sign-in

    #if DEBUG
    /// Simulator bypass: feeds `onSignIn` a stable fake credential so downstream state mirrors a real sign-in.
    private var devSignInButton: some View {
        Button {
            isWorking = true
            Task { @MainActor in
                defer { isWorking = false }
                do {
                    try await onSignIn(.devFixture)
                } catch {
                    inlineError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        } label: {
            Text("Skip (dev)")
                .font(PraccyFont.meta)
                .foregroundStyle(PraccyColor.ink60)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }
    #endif

    // MARK: - Signed-in card

    private var signedInCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(PraccyFont.section)
                    .foregroundStyle(palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = currentDisplayName, !name.isEmpty {
                        Text(name)
                            .font(PraccyFont.task)
                            .tracking(-0.2)
                            .foregroundStyle(PraccyColor.ink)
                    }
                    if let email = currentEmail, !email.isEmpty {
                        Text(email)
                            .font(PraccyFont.meta)
                            .foregroundStyle(PraccyColor.ink60)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PraccyRadius.card))
        .praccySolidShadow(color: palette.shadow.opacity(0.25), offset: 3)
    }
}

#if DEBUG
#Preview("Fresh") {
    SignInStep(
        palette: .violet,
        isSignedIn: false,
        currentDisplayName: nil,
        currentEmail: nil,
        onSignIn: { _ in }
    )
    .padding(24)
    .background(AccentPalette.violet.bg)
}

#Preview("Signed in") {
    SignInStep(
        palette: .violet,
        isSignedIn: true,
        currentDisplayName: "Luca",
        currentEmail: "luca@example.com",
        onSignIn: { _ in }
    )
    .padding(24)
    .background(AccentPalette.violet.bg)
}
#endif
