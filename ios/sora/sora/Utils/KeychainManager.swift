import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    func saveUserID(_ userID: String) {
        let data = Data(userID.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Constants.Keychain.userIDKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            AppLogger.auth.info("User ID saved to keychain")
        } else {
            AppLogger.auth.error("Failed to save user ID: \(status)")
        }
    }

    func getUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Constants.Keychain.userIDKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    func deleteUserID() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Constants.Keychain.userIDKey
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            AppLogger.auth.info("User ID deleted from keychain")
        } else {
            AppLogger.auth.error("Failed to delete user ID: \(status)")
        }
    }

    var isAuthenticated: Bool {
        getUserID() != nil
    }
}
