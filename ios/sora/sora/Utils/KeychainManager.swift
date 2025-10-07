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

        _ = SecItemAdd(query as CFDictionary, nil)
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

        _ = SecItemDelete(query as CFDictionary)
    }

    var isAuthenticated: Bool {
        getUserID() != nil
    }
}
