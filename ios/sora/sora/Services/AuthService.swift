import Foundation
import AuthenticationServices

protocol AuthServiceProtocol {
    func signInWithApple(identityToken: String) async throws -> AuthResponse
    func getCurrentUser() async throws -> User
    func signOut()
    var isAuthenticated: Bool { get }
}

final class AuthService: AuthServiceProtocol {
    static let shared = AuthService()

    private let networkManager: NetworkManager
    private let keychainManager: KeychainManager

    private init(
        networkManager: NetworkManager = .shared,
        keychainManager: KeychainManager = .shared
    ) {
        self.networkManager = networkManager
        self.keychainManager = keychainManager
    }

    var isAuthenticated: Bool {
        keychainManager.isAuthenticated
    }

    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        AppLogger.auth.info("Signing in with Apple")

        let request = AuthRequest(identityToken: identityToken)
        let response: AuthResponse = try await networkManager.request(
            .appleSignIn,
            body: request,
            requiresAuth: false
        )

        keychainManager.saveUserID(response.userId)

        AppLogger.auth.info("Sign in successful, user created: \(response.created)")

        return response
    }

    func getCurrentUser() async throws -> User {
        AppLogger.auth.info("Fetching current user")

        let user: User = try await networkManager.request(.getCurrentUser)

        return user
    }

    func signOut() {
        AppLogger.auth.info("Signing out")
        keychainManager.deleteUserID()
    }
}
