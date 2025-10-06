import Foundation

enum Constants {
    static let baseURL = "https://sora-engine.guitaripod.workers.dev"
    static let bundleID = "com.guitaripod.sora"

    enum Keychain {
        static let userIDKey = "user_id"
    }

    enum RevenueCat {
        static let apiKey = "YOUR_REVENUECAT_API_KEY"
        static let starterPackProductID = "sora_starter_pack"
    }

    enum Video {
        static let defaultModel = "sora-2"
        static let defaultDuration = 5
        static let defaultSize = "720x1280"
        static let maxPromptLength = 500
    }

    enum Credits {
        static let starterPackCredits = 1000
        static let starterPackPrice = "$9.99"
    }
}
