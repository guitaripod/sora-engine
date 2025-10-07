import Foundation
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = [] {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("StoreManagerDidUpdate"), object: nil)
        }
    }
    @Published private(set) var purchaseState: PurchaseState = .idle {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("StoreManagerDidUpdate"), object: nil)
        }
    }

    enum PurchaseState {
        case idle
        case purchasing
        case success(creditsAdded: Int64, newBalance: Int64)
        case failed(Error)
    }

    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        do {
            let loadedProducts = try await Product.products(for: [Constants.IAP.starterPackProductID])
            products = loadedProducts.sorted(by: { $0.price < $1.price })
        } catch {
            AppLogger.purchase.error("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let jwsRepresentation = verification.jwsRepresentation

                do {
                    let response = try await validateWithBackend(jwsRepresentation)
                    purchaseState = .success(
                        creditsAdded: response.creditsAdded,
                        newBalance: response.newBalance
                    )
                    await transaction.finish()
                } catch {
                    AppLogger.purchase.error("Backend validation failed: \(error.localizedDescription)")
                    purchaseState = .failed(error)
                    return
                }

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            AppLogger.purchase.error("Purchase failed: \(error.localizedDescription)")
            purchaseState = .failed(error)
        }
    }

    func resetPurchaseState() {
        purchaseState = .idle
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await verificationResult in Transaction.updates {
                guard case .verified(let transaction) = verificationResult else {
                    continue
                }

                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func validateWithBackend(_ transactionJWS: String) async throws -> AppleIAPValidateResponse {
        guard let url = URL(string: "\(Constants.baseURL)/v1/credits/purchase/apple/validate") else {
            throw StoreError.invalidURL
        }

        guard let userId = KeychainManager.shared.getUserID() else {
            throw StoreError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(userId)", forHTTPHeaderField: "Authorization")

        let requestBody = AppleIAPValidateRequest(transactionJws: transactionJWS)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StoreError.validationFailed
        }

        return try JSONDecoder().decode(AppleIAPValidateResponse.self, from: data)
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    case noJWSRepresentation
    case invalidURL
    case notAuthenticated
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .noJWSRepresentation:
            return "Unable to get transaction token"
        case .invalidURL:
            return "Invalid server URL"
        case .notAuthenticated:
            return "Please sign in to make purchases"
        case .validationFailed:
            return "Purchase validation failed"
        }
    }
}

struct AppleIAPValidateRequest: Codable {
    let transactionJws: String

    enum CodingKeys: String, CodingKey {
        case transactionJws = "transaction_jws"
    }
}

struct AppleIAPValidateResponse: Codable {
    let success: Bool
    let creditsAdded: Int64
    let newBalance: Int64
    let transactionId: String

    enum CodingKeys: String, CodingKey {
        case success
        case creditsAdded = "credits_added"
        case newBalance = "new_balance"
        case transactionId = "transaction_id"
    }
}
