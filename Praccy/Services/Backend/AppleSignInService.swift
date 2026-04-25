import AuthenticationServices
import Foundation

/// Adapts `ASAuthorizationAppleIDCredential` to the fields the backend consumes, and exposes
/// the cold-launch credential-state check.
@MainActor
enum AppleSignInService {

    /// `fullName` + `email` only arrive on first sign-in per Apple's rules.
    static func summarise(_ credential: ASAuthorizationAppleIDCredential) -> Summary {
        let joinedName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Summary(
            userIdentifier: credential.user,
            displayName: joinedName.isEmpty ? nil : joinedName,
            email: credential.email
        )
    }

    /// `.revoked` / `.notFound` means the user signed out of iCloud or disabled Apple ID access.
    static func credentialState(forUserIdentifier id: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    struct Summary: Equatable, Sendable {
        let userIdentifier: String
        let displayName: String?
        let email: String?
    }
}

#if DEBUG
extension AppleSignInService.Summary {
    /// Deterministic fake for the Simulator dev-bypass in `SignInStep` so repeat launches land on the same user.
    static let devFixture = AppleSignInService.Summary(
        userIdentifier: "dev.local.user",
        displayName: "Dev User",
        email: "dev@praccy.local"
    )
}
#endif
