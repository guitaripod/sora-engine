import Foundation

struct AuthRequest: Codable {
    let identityToken: String
}

struct AuthResponse: Codable {
    let userId: String
    let creditsBalance: Int
    let created: Bool
}

struct User: Codable {
    let id: String
    let creditsBalance: Int
    let totalVideosGenerated: Int
}

struct Video: Codable, Identifiable, Hashable {
    let id: String
    let status: VideoStatus
    let model: String
    let prompt: String
    let size: String
    let seconds: Int
    let creditsCost: Int
    let progress: Int
    let videoUrl: String?
    let thumbnailUrl: String?
    let spritesheetUrl: String?
    let downloadUrlExpiresAt: String?
    let errorMessage: String?
    let createdAt: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
}

enum VideoStatus: String, Codable {
    case queued
    case inProgress = "in_progress"
    case completed
    case failed

    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .inProgress: return "Generating"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

struct CreateVideoRequest: Codable {
    let model: String
    let prompt: String
    let size: String
    let seconds: Int
}

struct CreateVideoResponse: Codable {
    let id: String
    let status: VideoStatus
    let creditsCost: Int
    let newBalance: Int
    let estimatedWaitSeconds: Int
}

struct EstimateRequest: Codable {
    let model: String
    let size: String
    let seconds: Int
}

struct EstimateResponse: Codable {
    let creditsCost: Int
    let usdEquivalent: String
    let currentBalance: Int
    let sufficientCredits: Bool
}

struct VideoListResponse: Codable {
    let videos: [Video]
    let hasMore: Bool
    let totalCount: Int
}

struct CreditBalance: Codable {
    let creditsBalance: Int
    let usdEquivalent: String
}

struct CreditPack: Codable {
    let id: String
    let credits: Int
    let priceUsd: String
}

struct CreditPacksResponse: Codable {
    let packs: [CreditPack]
}

struct APIError: Codable {
    let error: String
    let message: String
}
