import Foundation
import AuthenticationServices

final class SignInViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol
    private weak var coordinator: AppCoordinator?

    init(
        coordinator: AppCoordinator,
        authService: AuthServiceProtocol = AuthService.shared
    ) {
        self.coordinator = coordinator
        self.authService = authService
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @MainActor
    private func handleSignIn(identityToken: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.signInWithApple(identityToken: identityToken)

            AppLogger.auth.info("Sign in successful, credits: \(response.creditsBalance)")

            coordinator?.showHome()
        } catch {
            AppLogger.auth.error("Sign in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

extension SignInViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Failed to get identity token"
            return
        }

        Task {
            await handleSignIn(identityToken: tokenString)
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        AppLogger.auth.error("Authorization failed: \(error.localizedDescription)")

        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            return
        }

        errorMessage = error.localizedDescription
    }
}

extension SignInViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
