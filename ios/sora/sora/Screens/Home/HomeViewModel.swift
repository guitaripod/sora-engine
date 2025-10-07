import Foundation
import Observation

@Observable
final class HomeViewModel {
    var credits: Int = 0
    var videos: [Video] = []
    var isLoading = false
    var errorMessage: String?
    var thumbnailReadyVideoId: String?
    var hasCompletedInitialLoad = false

    private let videoService: VideoServiceProtocol
    private let creditService: CreditServiceProtocol
    private weak var coordinator: AppCoordinator?
    private var refreshTimer: Timer?

    init(
        coordinator: AppCoordinator,
        videoService: VideoServiceProtocol = VideoService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.coordinator = coordinator
        self.videoService = videoService
        self.creditService = creditService
    }

    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadCredits()
            }
            group.addTask {
                await self.loadVideos()
            }
        }

        isLoading = false
        hasCompletedInitialLoad = true
        startAutoRefresh()
    }

    @MainActor
    func refreshData() async {
        await loadData()
    }

    @MainActor
    func createVideoTapped() {
        coordinator?.showCreateVideo()
    }

    @MainActor
    func videoTapped(_ video: Video) {
        if video.status == .completed, video.videoUrl != nil {
            coordinator?.showVideoPlayer(video: video)
        }
    }

    @MainActor
    func signOutTapped() {
        stopAutoRefresh()
        coordinator?.signOut()
    }

    @MainActor
    private func loadCredits() async {
        do {
            credits = try await creditService.getBalance()
        } catch {
            errorMessage = "Failed to load credits: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadVideos() async {
        do {
            let response = try await videoService.listVideos(limit: 50, offset: 0)
            videos = response.videos

            for video in videos where video.status == .completed {
                let isCached = VideoCacheManager.shared.isCached(videoId: video.id)
                let hasThumbnail = VideoThumbnailGenerator.shared.hasThumbnail(for: video.id)

                if !isCached || !hasThumbnail {
                    cacheVideoInBackground(video)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func startAutoRefresh() {
        guard hasActiveVideos else { return }

        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                await self?.refreshActiveVideos()
            }
        }
    }

    @MainActor
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    private func refreshActiveVideos() async {
        let activeVideos = videos.filter { $0.status == .queued || $0.status == .inProgress }

        for video in activeVideos {
            do {
                let updated = try await videoService.getVideo(id: video.id)

                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index] = updated

                    if updated.status == .completed, !VideoCacheManager.shared.isCached(videoId: updated.id) {
                        cacheVideoInBackground(updated)
                    }
                }
            } catch {
            }
        }

        if !hasActiveVideos {
            stopAutoRefresh()
        }

        await loadCredits()
    }

    private func cacheVideoInBackground(_ video: Video) {
        guard let videoURLString = video.videoUrl,
              let videoURL = URL(string: videoURLString) else {
            return
        }

        Task { @MainActor in
            do {
                try await VideoCacheManager.shared.downloadVideo(videoId: video.id, from: videoURL)

                let localURL = VideoCacheManager.shared.localURL(for: video.id)
                _ = try await VideoThumbnailGenerator.shared.generateThumbnail(for: localURL, videoId: video.id)

                thumbnailReadyVideoId = video.id
            } catch {
            }
        }
    }

    private var hasActiveVideos: Bool {
        videos.contains { $0.status == .queued || $0.status == .inProgress }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
