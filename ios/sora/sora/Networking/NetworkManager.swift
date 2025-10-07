import Foundation

enum APIEndpoint {
    case appleSignIn
    case getCurrentUser
    case createVideo
    case getVideo(String)
    case listVideos(limit: Int, offset: Int)
    case estimateCost
    case creditBalance
    case creditPacks

    var path: String {
        switch self {
        case .appleSignIn:
            return "/v1/auth/apple/token"
        case .getCurrentUser:
            return "/v1/auth/me"
        case .createVideo:
            return "/v1/videos"
        case .getVideo(let id):
            return "/v1/videos/\(id)"
        case .listVideos(let limit, let offset):
            return "/v1/videos?limit=\(limit)&offset=\(offset)"
        case .estimateCost:
            return "/v1/videos/estimate"
        case .creditBalance:
            return "/v1/credits/balance"
        case .creditPacks:
            return "/v1/credits/packs"
        }
    }

    var method: String {
        switch self {
        case .appleSignIn, .createVideo, .estimateCost:
            return "POST"
        case .getCurrentUser, .getVideo, .listVideos, .creditBalance, .creditPacks:
            return "GET"
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case insufficientCredits
    case rateLimitExceeded
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please sign in again"
        case .insufficientCredits:
            return "Insufficient credits. Please purchase more."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: Constants.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setJSONContentType()

        if requiresAuth, let userId = KeychainManager.shared.getUserID() {
            request.setBearerToken(userId)
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noData
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoded = try decoder.decode(T.self, from: data)
                    return decoded
                } catch {
                    throw NetworkError.decodingError(error)
                }

            case 401:
                throw NetworkError.unauthorized

            case 402:
                throw NetworkError.insufficientCredits

            case 429:
                throw NetworkError.rateLimitExceeded

            case 400...499, 500...599:
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw NetworkError.serverError(apiError.message)
                }
                throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")

            default:
                throw NetworkError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}
