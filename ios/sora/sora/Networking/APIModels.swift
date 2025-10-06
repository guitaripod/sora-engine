import Foundation

struct AuthRequest: Codable {
    let identityToken: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
    }
}

struct AuthResponse: Codable {
    let userId: String
    let creditsBalance: Int
    let created: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case creditsBalance = "credits_balance"
        case created
    }
}

struct User: Codable {
    let id: String
    let creditsBalance: Int
    let totalVideosGenerated: Int

    enum CodingKeys: String, CodingKey {
        case id
        case creditsBalance = "credits_balance"
        case totalVideosGenerated = "total_videos_generated"
    }
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

    enum CodingKeys: String, CodingKey {
        case id, status, model, prompt, size, seconds, progress
        case creditsCost = "credits_cost"
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case spritesheetUrl = "spritesheet_url"
        case downloadUrlExpiresAt = "download_url_expires_at"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }

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

    enum CodingKeys: String, CodingKey {
        case id, status
        case creditsCost = "credits_cost"
        case newBalance = "new_balance"
        case estimatedWaitSeconds = "estimated_wait_seconds"
    }
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

    enum CodingKeys: String, CodingKey {
        case creditsCost = "credits_cost"
        case usdEquivalent = "usd_equivalent"
        case currentBalance = "current_balance"
        case sufficientCredits = "sufficient_credits"
    }
}

struct VideoListResponse: Codable {
    let videos: [Video]
    let hasMore: Bool
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case videos
        case hasMore = "has_more"
        case totalCount = "total_count"
    }
}

struct CreditBalance: Codable {
    let balance: Int
}

struct CreditPack: Codable {
    let id: String
    let credits: Int
    let priceUsd: String

    enum CodingKeys: String, CodingKey {
        case id, credits
        case priceUsd = "price_usd"
    }
}

struct CreditPacksResponse: Codable {
    let packs: [CreditPack]
}

struct APIError: Codable {
    let error: String
    let message: String
}
