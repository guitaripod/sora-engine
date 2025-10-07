import Foundation

protocol VideoServiceProtocol {
    func estimateCost(model: String, size: String, seconds: Int) async throws -> EstimateResponse
    func createVideo(model: String, prompt: String, size: String, seconds: Int) async throws -> CreateVideoResponse
    func getVideo(id: String) async throws -> Video
    func listVideos(limit: Int, offset: Int) async throws -> VideoListResponse
}

final class VideoService: VideoServiceProtocol {
    static let shared = VideoService()

    private let networkManager: NetworkManager

    private init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    func estimateCost(model: String, size: String, seconds: Int) async throws -> EstimateResponse {
        let request = EstimateRequest(model: model, size: size, seconds: seconds)
        let response: EstimateResponse = try await networkManager.request(
            .estimateCost,
            body: request
        )

        return response
    }

    func createVideo(model: String, prompt: String, size: String, seconds: Int) async throws -> CreateVideoResponse {
        let request = CreateVideoRequest(model: model, prompt: prompt, size: size, seconds: seconds)
        let response: CreateVideoResponse = try await networkManager.request(
            .createVideo,
            body: request
        )

        return response
    }

    func getVideo(id: String) async throws -> Video {
        let video: Video = try await networkManager.request(.getVideo(id))
        return video
    }

    func listVideos(limit: Int = 20, offset: Int = 0) async throws -> VideoListResponse {
        let response: VideoListResponse = try await networkManager.request(
            .listVideos(limit: limit, offset: offset)
        )

        return response
    }
}
