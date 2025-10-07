import Foundation

protocol CreditServiceProtocol {
    func getBalance() async throws -> Int
    func getCreditPacks() async throws -> [CreditPack]
}

final class CreditService: CreditServiceProtocol {
    static let shared = CreditService()

    private let networkManager: NetworkManager

    private init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    func getBalance() async throws -> Int {
        let response: CreditBalance = try await networkManager.request(.creditBalance)
        return response.creditsBalance
    }

    func getCreditPacks() async throws -> [CreditPack] {
        let response: CreditPacksResponse = try await networkManager.request(.creditPacks)
        return response.packs
    }
}
